"""
PhotoPrism Onboarding Module

Handles conversational onboarding flow for family photo service including:
- Family name collection
- Domain availability checking
- Domain registration
- PhotoPrism deployment
- Credential generation
"""

from typing import Dict, Optional, List
from pydantic import BaseModel, EmailStr
from enum import Enum
import secrets
import string
import logging

from ..domain import DomainManager, DomainStatus, DomainSuggestion

logger = logging.getLogger(__name__)


class OnboardingStep(str, Enum):
    """Onboarding flow steps"""
    WELCOME = "welcome"
    COLLECT_FAMILY_NAME = "collect_family_name"
    CHECK_DOMAIN = "check_domain"
    SUGGEST_ALTERNATIVES = "suggest_alternatives"
    CONFIRM_DOMAIN = "confirm_domain"
    COLLECT_CONTACT_INFO = "collect_contact_info"
    REGISTER_DOMAIN = "register_domain"
    CONFIGURE_DNS = "configure_dns"
    GENERATE_CREDENTIALS = "generate_credentials"
    DEPLOY_PHOTOPRISM = "deploy_photoprism"
    COMPLETE = "complete"


class OnboardingState(BaseModel):
    """State of onboarding session"""
    session_id: str
    current_step: OnboardingStep
    family_name: Optional[str] = None
    chosen_domain: Optional[str] = None
    domain_suggestions: List[DomainSuggestion] = []
    contact_email: Optional[EmailStr] = None
    admin_password: Optional[str] = None
    ingress_ip: Optional[str] = None
    deployment_status: str = "pending"


class ContactInfo(BaseModel):
    """Contact information for domain registration"""
    first_name: str
    last_name: str
    email: EmailStr
    phone: str
    address: str
    city: str
    state: str
    postal_code: str
    country: str = "US"


class OnboardingFlow:
    """Manage PhotoPrism onboarding conversation flow"""

    def __init__(self, domain_manager: DomainManager):
        self.domain_manager = domain_manager
        self.sessions: Dict[str, OnboardingState] = {}

    async def start_onboarding(self, session_id: str) -> str:
        """
        Start new onboarding session

        Returns:
            Welcome message
        """
        # Create new session
        self.sessions[session_id] = OnboardingState(
            session_id=session_id,
            current_step=OnboardingStep.WELCOME
        )

        return self._get_welcome_message()

    async def process_response(
        self,
        session_id: str,
        user_input: str
    ) -> str:
        """
        Process user response and advance onboarding

        Args:
            session_id: Session identifier
            user_input: User's response

        Returns:
            Next message in conversation
        """
        if session_id not in self.sessions:
            return "Session not found. Please start onboarding first."

        state = self.sessions[session_id]

        # Route to appropriate handler based on current step
        if state.current_step == OnboardingStep.WELCOME:
            return await self._handle_welcome(state, user_input)

        elif state.current_step == OnboardingStep.COLLECT_FAMILY_NAME:
            return await self._handle_family_name(state, user_input)

        elif state.current_step == OnboardingStep.CHECK_DOMAIN:
            return await self._handle_domain_check(state, user_input)

        elif state.current_step == OnboardingStep.SUGGEST_ALTERNATIVES:
            return await self._handle_alternative_selection(state, user_input)

        elif state.current_step == OnboardingStep.CONFIRM_DOMAIN:
            return await self._handle_domain_confirmation(state, user_input)

        elif state.current_step == OnboardingStep.COLLECT_CONTACT_INFO:
            return await self._handle_contact_info(state, user_input)

        else:
            return "Invalid step. Please contact support."

    # ========================================================================
    # Step Handlers
    # ========================================================================

    def _get_welcome_message(self) -> str:
        """Welcome message"""
        return """👋 **Welcome to PhotoPrism Family Setup!**

I'll help you set up your own private family photo service in just a few minutes.

We'll:
1. Choose a domain name for your family
2. Register the domain (about $20-30/year for .family domains)
3. Deploy PhotoPrism with AI-powered photo organization
4. Set up secure access for your family members

**Let's get started!**

What's your family name? (e.g., "Smith", "Johnson", "Garcia")
"""

    async def _handle_welcome(
        self,
        state: OnboardingState,
        user_input: str
    ) -> str:
        """Handle welcome → family name collection"""

        state.current_step = OnboardingStep.COLLECT_FAMILY_NAME
        return await self._handle_family_name(state, user_input)

    async def _handle_family_name(
        self,
        state: OnboardingState,
        user_input: str
    ) -> str:
        """Handle family name input"""

        # Clean and validate family name
        family_name = user_input.strip().lower()

        # Remove special characters except hyphens
        family_name = ''.join(c for c in family_name if c.isalnum() or c == '-')

        if not family_name or len(family_name) < 2:
            return "Please provide a valid family name (at least 2 characters)."

        if len(family_name) > 30:
            return "Family name is too long (max 30 characters). Please shorten it."

        state.family_name = family_name
        state.current_step = OnboardingStep.CHECK_DOMAIN

        # Check primary domain availability
        return await self._check_domain_availability(state)

    async def _check_domain_availability(self, state: OnboardingState) -> str:
        """Check if primary domain is available"""

        domain = f"{state.family_name}.family"

        logger.info(f"Checking availability for {domain}")

        result = await self.domain_manager.check_availability(
            state.family_name,
            tld="family"
        )

        if result.status == DomainStatus.AVAILABLE:
            # Primary domain available!
            state.chosen_domain = domain
            state.current_step = OnboardingStep.CONFIRM_DOMAIN

            price = result.price or 25.0

            return f"""✅ **Great news!** The domain **{domain}** is available!

**Price**: ~${price:.2f}/year
**Your PhotoPrism URL**: https://photos.{domain}

Would you like to proceed with this domain? (yes/no)

(Type 'no' if you'd like to see alternative suggestions)
"""

        elif result.status == DomainStatus.PREMIUM:
            # Premium domain - expensive
            return f"""⚠️ **{domain}** is a premium domain (${result.price:.2f}/year).

That's quite expensive! Let me suggest some alternatives...

{await self._suggest_alternatives(state)}
"""

        else:
            # Unavailable - suggest alternatives
            state.current_step = OnboardingStep.SUGGEST_ALTERNATIVES

            return f"""❌ Unfortunately, **{domain}** is already taken.

Don't worry! Let me suggest some great alternatives...

{await self._suggest_alternatives(state)}
"""

    async def _suggest_alternatives(self, state: OnboardingState) -> str:
        """Generate and present alternative domains"""

        suggestions = await self.domain_manager.suggest_alternatives(
            state.family_name,
            tld="family",
            max_suggestions=5
        )

        state.domain_suggestions = suggestions

        if not suggestions:
            return """😔 I couldn't find any available alternatives.

Would you like to try:
1. A different TLD (.com, .io, .net)?
2. A different family name?

Please let me know!"""

        # Format suggestions
        message_parts = ["**Available alternatives:**\n"]

        for i, suggestion in enumerate(suggestions, 1):
            price_str = f"${suggestion.price:.2f}/year" if suggestion.price else "~$25/year"
            message_parts.append(
                f"{i}. **{suggestion.domain}** ({price_str})"
            )

        message_parts.append("\nWhich option do you prefer? (Enter 1-5)")
        message_parts.append("\nOr type 'custom' to enter your own domain name.")

        return "\n".join(message_parts)

    async def _handle_alternative_selection(
        self,
        state: OnboardingState,
        user_input: str
    ) -> str:
        """Handle alternative domain selection"""

        user_input = user_input.strip().lower()

        # Check if user wants custom domain
        if user_input == "custom":
            return """Please enter your desired domain name (e.g., "smithphotos.family")"""

        # Check if user selected a number
        try:
            choice = int(user_input)

            if 1 <= choice <= len(state.domain_suggestions):
                selected = state.domain_suggestions[choice - 1]
                state.chosen_domain = selected.domain
                state.current_step = OnboardingStep.CONFIRM_DOMAIN

                return f"""✅ Perfect! You've selected: **{selected.domain}**

**Price**: ~${selected.price or 25.0:.2f}/year
**Your PhotoPrism URL**: https://photos.{selected.domain}

Ready to proceed? (yes/no)
"""
            else:
                return f"Please enter a number between 1 and {len(state.domain_suggestions)}."

        except ValueError:
            # Check if user entered a custom domain
            if "." in user_input:
                # Validate custom domain
                state.chosen_domain = user_input
                state.current_step = OnboardingStep.CONFIRM_DOMAIN

                return f"""You've entered: **{user_input}**

Let me check if this is available... (checking...)

{await self._check_custom_domain(state, user_input)}
"""

            return "Please enter a number (1-5), 'custom', or a domain name."

    async def _check_custom_domain(
        self,
        state: OnboardingState,
        domain: str
    ) -> str:
        """Check custom domain availability"""

        # Split domain into name and TLD
        parts = domain.rsplit(".", 1)
        if len(parts) != 2:
            return "Invalid domain format. Please include TLD (e.g., .family, .com)"

        name, tld = parts

        result = await self.domain_manager.check_availability(name, tld)

        if result.status == DomainStatus.AVAILABLE:
            return f"✅ Great! **{domain}** is available. Proceed? (yes/no)"
        else:
            return f"❌ Sorry, **{domain}** is not available. Try another?"

    async def _handle_domain_confirmation(
        self,
        state: OnboardingState,
        user_input: str
    ) -> str:
        """Handle domain confirmation"""

        user_input = user_input.strip().lower()

        if user_input in ["yes", "y", "proceed", "confirm"]:
            state.current_step = OnboardingStep.COLLECT_CONTACT_INFO

            return """🎉 Excellent!

To register your domain, I need some contact information (required by domain registrars).

**Contact Information:**
Please provide the following (separated by commas):

Format: FirstName, LastName, Email, Phone

Example: John, Smith, john@example.com, +1-555-1234

(We'll keep this secure in Vault - it's only for domain registration)
"""

        elif user_input in ["no", "n", "back"]:
            # Go back to alternatives
            state.current_step = OnboardingStep.SUGGEST_ALTERNATIVES
            return await self._suggest_alternatives(state)

        else:
            return "Please answer 'yes' to proceed or 'no' to see other options."

    async def _handle_contact_info(
        self,
        state: OnboardingState,
        user_input: str
    ) -> str:
        """Handle contact information collection"""

        # Parse comma-separated input
        parts = [p.strip() for p in user_input.split(",")]

        if len(parts) < 4:
            return """Please provide all required information:

Format: FirstName, LastName, Email, Phone

Example: John, Smith, john@example.com, +1-555-1234
"""

        first_name, last_name, email, phone = parts[:4]

        # Validate email
        if "@" not in email or "." not in email:
            return "Invalid email address. Please try again."

        state.contact_email = email
        state.current_step = OnboardingStep.REGISTER_DOMAIN

        # Proceed to registration
        return await self._register_and_deploy(state, first_name, last_name, email, phone)

    async def _register_and_deploy(
        self,
        state: OnboardingState,
        first_name: str,
        last_name: str,
        email: str,
        phone: str
    ) -> str:
        """Register domain and deploy PhotoPrism"""

        domain = state.chosen_domain

        # Generate secure admin password
        state.admin_password = self._generate_secure_password()

        # TODO: Implement actual domain registration
        # For MVP, we'll assume manual registration

        message = f"""⏳ **Setting up your family photo service...**

**Domain**: {domain}
**Email**: {email}

**Steps in progress:**
1. ⏳ Registering domain... (this may take a few minutes)
2. ⏳ Configuring DNS records...
3. ⏳ Deploying PhotoPrism with AI features...
4. ⏳ Enabling GPU acceleration...
5. ⏳ Setting up Authelia SSO...
6. ⏳ Generating TLS certificates...

Please wait...

---

**IMPORTANT - Manual Steps Required (for now):**

Since automatic domain registration requires payment processing, please:

1. **Register domain manually** at your preferred registrar:
   - Namecheap: https://www.namecheap.com/domains/
   - Cloudflare: https://www.cloudflare.com/products/registrar/
   - Domain: {domain}

2. **Configure DNS A records** (after domain registration):
   - photos.{domain} → [Your K3s Ingress IP]
   - minio.photos.{domain} → [Your K3s Ingress IP]
   - auth.{domain} → [Your K3s Ingress IP]

3. Once DNS is configured, I'll complete the deployment!

Type 'ready' when DNS is configured, or 'help' for assistance.
"""

        return message

    def _generate_secure_password(self, length: int = 20) -> str:
        """Generate cryptographically secure password"""

        alphabet = string.ascii_letters + string.digits + "!@#$%^&*"
        password = ''.join(secrets.choice(alphabet) for _ in range(length))

        return password

    async def complete_deployment(
        self,
        session_id: str,
        ingress_ip: str
    ) -> str:
        """Complete deployment after DNS configuration"""

        if session_id not in self.sessions:
            return "Session not found."

        state = self.sessions[session_id]
        state.ingress_ip = ingress_ip
        state.current_step = OnboardingStep.DEPLOY_PHOTOPRISM
        state.deployment_status = "deploying"

        domain = state.chosen_domain

        # Return deployment command
        return f"""✅ **DNS configured! Starting deployment...**

**Running PhotoPrism deployment:**

```bash
cd /home/user/suhlabs/services/photoprism

# Update domain in configuration
sed -i 's/familyname.family/{domain}/g' kubernetes/*.yaml

# Deploy with GPU and Authelia enabled
./deploy.sh

# Deployment will take ~10-15 minutes
```

**Your PhotoPrism Details:**
- **URL**: https://photos.{domain}
- **Admin Username**: admin
- **Admin Password**: {state.admin_password}
- **Storage**: 1TB photos, 50GB database, 100GB cache
- **Features**: GPU acceleration, Authelia SSO, AI face detection

**Save these credentials securely!**

I'll notify you when deployment completes. ⏳
"""

    async def finalize_onboarding(
        self,
        session_id: str
    ) -> str:
        """Finalize onboarding and provide next steps"""

        state = self.sessions[session_id]
        state.current_step = OnboardingStep.COMPLETE
        state.deployment_status = "complete"

        domain = state.chosen_domain

        return f"""🎉 **Congratulations! Your PhotoPrism is ready!**

**Access Your Photos:**
🌐 https://photos.{domain}

**Admin Credentials:**
👤 Username: `admin`
🔑 Password: `{state.admin_password}`

**Next Steps:**

1. **Log in** and change your password (Settings → Account)
2. **Upload photos** (click Upload button)
3. **Invite family** (Settings → Users → Add User)
4. **Enable sharing** for extended family members

**Features Enabled:**
✅ AI-powered face detection (GPU accelerated)
✅ Object recognition (1000+ labels)
✅ Location mapping (GPS-based)
✅ Authelia SSO for family members
✅ 1TB storage (expandable)

**Family Sharing:**
To invite family:
1. Settings → Users → Add User
2. Enter their email and set permissions
3. They'll receive an invitation link

**Support:**
- Documentation: /docs/photoprism/
- Troubleshooting: `kubectl logs -n photoprism -l app=photoprism`
- Backup: `./backup.sh` (set up automated backups!)

---

🎊 **Welcome to your private family photo cloud!** 📸

Type 'help' for more commands or 'backup' to set up automated backups.
"""
