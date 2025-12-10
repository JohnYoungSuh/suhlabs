
from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import logging

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - GOVERNANCE_MOCK - %(message)s')

class GovernanceHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path == '/api/v1/authorize':
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            
            try:
                data = json.loads(post_data)
                action_type = data.get('action_type')
                risk_data = data.get('risk_data')
                
                logging.info(f"Received Authorization Request: Action={action_type}, Risk={risk_data}")
                
                # Mock Logic:
                # - Deny if risk_data string contains "HIGH_RISK"
                # - Allow otherwise
                
                if "HIGH_RISK" in str(risk_data):
                    self.send_response(403)
                    self.send_header('Content-type', 'application/json')
                    self.end_headers()
                    response = {"result": "DENIED", "reason": "Risk level too high for automated approval."}
                    logging.info("Decision: DENIED")
                else:
                    self.send_response(200)
                    self.send_header('Content-type', 'application/json')
                    self.end_headers()
                    response = {"result": "ALLOWED", "reason": "Policy checks passed."}
                    logging.info("Decision: ALLOWED")
                    
                self.wfile.write(json.dumps(response).encode('utf-8'))
                
            except json.JSONDecodeError:
                self.send_response(400)
                self.end_headers()
                logging.error("Failed to decode JSON body")
        else:
            self.send_response(404)
            self.end_headers()

def run(server_class=HTTPServer, handler_class=GovernanceHandler, port=8080):
    server_address = ('', port)
    httpd = server_class(server_address, handler_class)
    logging.info(f"Starting Mock Governance Service on port {port}...")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    httpd.server_close()
    logging.info("Stopping Mock Governance Service")

if __name__ == '__main__':
    run()
