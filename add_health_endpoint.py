import sys

# Read the file
with open('run_ui.py', 'r') as f:
    content = f.read()

# Find the location to insert the health endpoint (before the run() function)
insert_marker = 'def run():'
insert_pos = content.find(insert_marker)

if insert_pos == -1:
    print("Error: Could not find insertion point")
    sys.exit(1)

# Health endpoint code to insert
health_endpoint = '''# Health check endpoint for Railway
@webapp.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint for Railway deployment."""
    return {"status": "healthy", "service": "agent-zero"}, 200

'''

# Insert the health endpoint
new_content = content[:insert_pos] + health_endpoint + content[insert_pos:]

# Write back to file
with open('run_ui.py', 'w') as f:
    f.write(new_content)

print("Health endpoint added successfully!")
