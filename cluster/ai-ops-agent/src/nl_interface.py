"""
Natural Language Interface for Non-Technical Users
Converts user requests into infrastructure actions
"""

from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass
from enum import Enum
import json
import re


class Intent(Enum):
    """Supported user intents"""
    CREATE_ENVIRONMENT = "create_environment"
    DELETE_ENVIRONMENT = "delete_environment"
    DEPLOY_APP = "deploy_app"
    SCALE_APP = "scale_app"
    TROUBLESHOOT = "troubleshoot"
    SHOW_USAGE = "show_usage"
    ADD_DATABASE = "add_database"
    CREATE_BACKUP = "create_backup"
    LIST_PERMISSIONS = "list_permissions"
    RESTART_APP = "restart_app"
    VIEW_LOGS = "view_logs"
    UNKNOWN = "unknown"


@dataclass
class UserContext:
    """User information and permissions"""
    username: str
    groups: List[str]
    team: str
    quota_cpu: float  # CPU cores
    quota_memory: float  # GB
    quota_storage: float  # GB
    budget: float  # Monthly budget in $


@dataclass
class ParsedIntent:
    """Parsed user intent with extracted parameters"""
    intent: Intent
    confidence: float
    parameters: Dict
    requires_approval: bool
    estimated_cost: Optional[float] = None


class NLInterfaceEngine:
    """
    Natural Language Interface Engine
    
    Processes user requests in plain English and converts them
    to infrastructure actions.
    """
    
    # Intent patterns (simple regex, can be replaced with LLM)
    INTENT_PATTERNS = {
        Intent.CREATE_ENVIRONMENT: [
            r"create.*environment",
            r"need.*environment",
            r"set up.*environment",
            r"new.*environment",
        ],
        Intent.DELETE_ENVIRONMENT: [
            r"delete.*environment",
            r"remove.*environment",
            r"destroy.*environment",
        ],
        Intent.DEPLOY_APP: [
            r"deploy.*app",
            r"deploy.*application",
            r"install.*app",
            r"need.*wordpress",
            r"need.*database",
        ],
        Intent.SCALE_APP: [
            r"scale up",
            r"scale down",
            r"add more resources",
            r"app is slow",
            r"need more.*",
        ],
        Intent.TROUBLESHOOT: [
            r"not working",
            r"is down",
            r"app crashed",
            r"getting error",
            r"what's wrong",
            r"why.*not.*",
        ],
        Intent.SHOW_USAGE: [
            r"how much.*using",
            r"show.*usage",
            r"what's my.*quota",
            r"resource.*usage",
        ],
        Intent.ADD_DATABASE: [
            r"need.*database",
            r"add.*database",
            r"create.*database",
            r"deploy.*postgres",
            r"deploy.*mysql",
        ],
        Intent.VIEW_LOGS: [
            r"show.*logs",
            r"view.*logs",
            r"check.*logs",
            r"what happened",
        ],
        Intent.RESTART_APP: [
            r"restart",
            r"reboot",
            r"reset",
        ],
    }
    
    def __init__(self, ollama_client, vault_client, k8s_client):
        self.ollama = ollama_client
        self.vault = vault_client
        self.k8s = k8s_client
    
    def process_request(
        self,
        user_input: str,
        user_context: UserContext
    ) -> Dict:
        """
        Main entry point for processing user requests.
        
        Args:
            user_input: Natural language input from user
            user_context: User information and permissions
            
        Returns:
            Response dictionary with action results
        """
        # 1. Parse intent
        parsed = self.parse_intent(user_input)
        
        # 2. Validate permission
        if not self.check_permission(parsed.intent, user_context):
            return {
                "status": "error",
                "message": "Sorry, you don't have permission for this action. "
                          "Contact your admin if you need access.",
                "suggestions": self._get_allowed_actions(user_context)
            }
        
        # 3. Check quotas
        if not self.check_quotas(parsed, user_context):
            return {
                "status": "error",
                "message": f"This would exceed your team's resource quota. "
                          f"Current usage: {self._get_current_usage(user_context)}",
                "suggestions": ["Contact admin to increase quota", "Delete unused resources"]
            }
        
        # 4. Estimate cost if applicable
        if parsed.estimated_cost:
            cost_warning = self._check_budget(parsed.estimated_cost, user_context)
            if cost_warning:
                return {
                    "status": "confirmation_needed",
                    "message": cost_warning,
                    "action": parsed,
                    "requires_confirmation": True
                }
        
        # 5. Check if approval needed
        if parsed.requires_approval:
            return {
                "status": "approval_needed",
                "message": "This action requires approval from your team lead.",
                "action": parsed,
                "approval_link": self._create_approval_request(parsed, user_context)
            }
        
        # 6. Execute action
        try:
            result = self.execute_action(parsed, user_context)
            return {
                "status": "success",
                "message": self._format_success_message(result),
                "details": result
            }
        except Exception as e:
            return {
                "status": "error",
                "message": f"Failed to execute action: {str(e)}",
                "help": "Try asking 'what's wrong with my app' for troubleshooting."
            }
    
    def parse_intent(self, user_input: str) -> ParsedIntent:
        """
        Parse user input to determine intent and extract parameters.
        
        Uses both pattern matching and LLM for better accuracy.
        """
        user_input_lower = user_input.lower()
        
        # First pass: Pattern matching for quick common intents
        for intent, patterns in self.INTENT_PATTERNS.items():
            for pattern in patterns:
                if re.search(pattern, user_input_lower):
                    return ParsedIntent(
                        intent=intent,
                        confidence=0.8,
                        parameters=self._extract_parameters(user_input, intent),
                        requires_approval=self._requires_approval(intent)
                    )
        
        # Second pass: Use LLM for complex queries
        llm_result = self._llm_parse_intent(user_input)
        return llm_result
    
    def _llm_parse_intent(self, user_input: str) -> ParsedIntent:
        """Use Ollama LLM to parse complex intents"""
        prompt = f"""
You are an AI assistant for infrastructure management. 
Parse this user request and respond with JSON:

User: "{user_input}"

Respond with:
{{
    "intent": "create_environment|deploy_app|scale_app|troubleshoot|...",
    "confidence": 0.0-1.0,
    "parameters": {{
        "app_name": "...",
        "resource_type": "...",
        "action": "..."
    }},
    "requires_approval": true|false
}}

Supported intents:
- create_environment: User wants a new namespace/environment
- deploy_app: User wants to deploy an application
- scale_app: User wants to change resources
- troubleshoot: User has a problem with their app
- show_usage: User wants to see resource usage
- add_database: User needs a database
- view_logs: User wants to see logs
- restart_app: User wants to restart their app

JSON:
"""
        
        response = self.ollama.generate(
            model="llama3.1:8b",
            prompt=prompt,
            stream=False
        )
        
        try:
            result = json.loads(response['response'])
            return ParsedIntent(
                intent=Intent(result['intent']),
                confidence=result['confidence'],
                parameters=result['parameters'],
                requires_approval=result['requires_approval']
            )
        except:
            return ParsedIntent(
                intent=Intent.UNKNOWN,
                confidence=0.0,
                parameters={},
                requires_approval=False
            )
    
    def _extract_parameters(self, user_input: str, intent: Intent) -> Dict:
        """Extract parameters from user input based on intent"""
        params = {}
        
        # Extract app/environment names
        words = user_input.split()
        for i, word in enumerate(words):
            if word.lower() in ['called', 'named', 'for']:
                if i + 1 < len(words):
                    params['name'] = words[i + 1].strip('.,!?')
        
        # Extract resource specifications
        if 'cpu' in user_input.lower():
            cpu_match = re.search(r'(\d+)\s*cpu', user_input.lower())
            if cpu_match:
                params['cpu'] = int(cpu_match.group(1))
        
        if 'memory' in user_input.lower() or 'ram' in user_input.lower():
            mem_match = re.search(r'(\d+)\s*gb', user_input.lower())
            if mem_match:
                params['memory'] = int(mem_match.group(1))
        
        # Extract database type
        if any(db in user_input.lower() for db in ['postgres', 'postgresql']):
            params['database_type'] = 'postgresql'
        elif 'mysql' in user_input.lower():
            params['database_type'] = 'mysql'
        elif 'mongo' in user_input.lower():
            params['database_type'] = 'mongodb'
        
        return params
    
    def check_permission(self, intent: Intent, user_context: UserContext) -> bool:
        """Check if user has permission for this intent"""
        # Map intents to required groups
        permission_map = {
            Intent.CREATE_ENVIRONMENT: ['developers', 'admins'],
            Intent.DELETE_ENVIRONMENT: ['admins'],
            Intent.DEPLOY_APP: ['developers', 'admins'],
            Intent.SCALE_APP: ['developers', 'admins'],
            Intent.TROUBLESHOOT: ['users', 'developers', 'admins'],
            Intent.SHOW_USAGE: ['users', 'developers', 'admins'],
            Intent.ADD_DATABASE: ['developers', 'admins'],
            Intent.VIEW_LOGS: ['developers', 'admins'],
            Intent.RESTART_APP: ['developers', 'admins'],
        }
        
        required_groups = permission_map.get(intent, ['admins'])
        return any(group in user_context.groups for group in required_groups)
    
    def check_quotas(self, parsed: ParsedIntent, user_context: UserContext) -> bool:
        """Check if action would exceed user's quota"""
        # Get current usage
        current = self._get_current_usage(user_context)
        
        # Estimate new usage based on intent
        estimated_cpu = parsed.parameters.get('cpu', 1)
        estimated_memory = parsed.parameters.get('memory', 2)
        
        if parsed.intent in [Intent.CREATE_ENVIRONMENT, Intent.DEPLOY_APP, Intent.ADD_DATABASE]:
            if (current['cpu'] + estimated_cpu > user_context.quota_cpu or
                current['memory'] + estimated_memory > user_context.quota_memory):
                return False
        
        return True
    
    def execute_action(self, parsed: ParsedIntent, user_context: UserContext) -> Dict:
        """Execute the parsed action"""
        if parsed.intent == Intent.CREATE_ENVIRONMENT:
            return self._create_environment(parsed.parameters, user_context)
        elif parsed.intent == Intent.DEPLOY_APP:
            return self._deploy_app(parsed.parameters, user_context)
        elif parsed.intent == Intent.SCALE_APP:
            return self._scale_app(parsed.parameters, user_context)
        elif parsed.intent == Intent.TROUBLESHOOT:
            return self._troubleshoot(parsed.parameters, user_context)
        elif parsed.intent == Intent.SHOW_USAGE:
            return self._show_usage(user_context)
        elif parsed.intent == Intent.ADD_DATABASE:
            return self._add_database(parsed.parameters, user_context)
        elif parsed.intent == Intent.VIEW_LOGS:
            return self._view_logs(parsed.parameters, user_context)
        elif parsed.intent == Intent.RESTART_APP:
            return self._restart_app(parsed.parameters, user_context)
        else:
            raise ValueError(f"Unknown intent: {parsed.intent}")
    
    def _create_environment(self, params: Dict, user_context: UserContext) -> Dict:
        """Create a new Kubernetes namespace with resources"""
        env_name = params.get('name', f"{user_context.team}-env-{self._generate_id()}")
        
        # Create namespace
        namespace = {
            "apiVersion": "v1",
            "kind": "Namespace",
            "metadata": {
                "name": env_name,
                "labels": {
                    "team": user_context.team,
                    "owner": user_context.username,
                    "managed-by": "aiops-agent"
                }
            }
        }
        
        self.k8s.create_namespace(namespace)
        
        # Apply resource quotas
        quota = {
            "apiVersion": "v1",
            "kind": "ResourceQuota",
            "metadata": {
                "name": "team-quota",
                "namespace": env_name
            },
            "spec": {
                "hard": {
                    "requests.cpu": f"{user_context.quota_cpu}",
                    "requests.memory": f"{user_context.quota_memory}Gi",
                    "persistentvolumeclaims": "10"
                }
            }
        }
        
        self.k8s.create_resource_quota(namespace=env_name, body=quota)
        
        return {
            "environment": env_name,
            "namespace": env_name,
            "quota": {
                "cpu": user_context.quota_cpu,
                "memory": f"{user_context.quota_memory}Gi"
            },
            "access_url": f"https://{env_name}.corp.example.com"
        }
    
    def _deploy_app(self, params: Dict, user_context: UserContext) -> Dict:
        """Deploy an application (WordPress, database, etc.)"""
        # Implementation would create Deployment, Service, Ingress
        pass
    
    def _scale_app(self, params: Dict, user_context: UserContext) -> Dict:
        """Scale application resources"""
        # Implementation would patch Deployment with new resources
        pass
    
    def _troubleshoot(self, params: Dict, user_context: UserContext) -> Dict:
        """Troubleshoot application issues"""
        # Implementation would:
        # 1. Get pod status
        # 2. Check recent events
        # 3. Analyze logs
        # 4. Suggest fixes
        pass
    
    def _show_usage(self, user_context: UserContext) -> Dict:
        """Show resource usage"""
        return self._get_current_usage(user_context)
    
    def _get_current_usage(self, user_context: UserContext) -> Dict:
        """Get current resource usage for user's team"""
        # Query Kubernetes for actual usage
        # For now, return mock data
        return {
            "cpu": 2.5,
            "memory": 8.0,
            "storage": 50.0,
            "percentage": {
                "cpu": (2.5 / user_context.quota_cpu) * 100,
                "memory": (8.0 / user_context.quota_memory) * 100
            }
        }
    
    def _format_success_message(self, result: Dict) -> str:
        """Format success message for user"""
        if 'environment' in result:
            return f"""
Environment created! 🎉

Name: {result['environment']}
Access: {result['access_url']}
Quota: {result['quota']['cpu']} CPU, {result['quota']['memory']} memory

You can now deploy applications to this environment.
"""
        return "Action completed successfully!"
    
    def _requires_approval(self, intent: Intent) -> bool:
        """Check if intent requires approval"""
        approval_required = [
            Intent.DELETE_ENVIRONMENT,
            Intent.CREATE_BACKUP
        ]
        return intent in approval_required
    
    def _check_budget(self, cost: float, user_context: UserContext) -> Optional[str]:
        """Check if cost is within budget"""
        if cost > user_context.budget * 0.1:  # More than 10% of budget
            return f"""
This action will cost approximately ${cost:.2f}/month.
This is {(cost/user_context.budget)*100:.1f}% of your team's budget (${user_context.budget}/month).

Do you want to proceed?
"""
        return None
    
    def _generate_id(self) -> str:
        """Generate a short random ID"""
        import random
        import string
        return ''.join(random.choices(string.ascii_lowercase + string.digits, k=6))
    
    def _get_allowed_actions(self, user_context: UserContext) -> List[str]:
        """Get list of actions user is allowed to perform"""
        if 'admins' in user_context.groups:
            return ["All actions available"]
        elif 'developers' in user_context.groups:
            return [
                "Create environments",
                "Deploy applications",
                "Scale resources",
                "View logs",
                "Restart applications"
            ]
        else:
            return [
                "View usage",
                "Troubleshoot (view only)"
            ]
    
    def _create_approval_request(self, parsed: ParsedIntent, user_context: UserContext) -> str:
        """Create approval request link"""
        # Would integrate with approval system
        return f"https://portal.corp.example.com/approvals/new?intent={parsed.intent}&user={user_context.username}"
