import base64
import requests
import json
import re
import os


def retrieve_url():
    return 'http://localhost:8080/2015-03-31/functions/function/invocations'

def encode_file_to_base64(file_path):
    """Local audio files sent to AWS Lambda must be encoded to base64."""
    with open(file_path, 'rb') as file:
        encoded_content = base64.b64encode(file.read())
    return encoded_content.decode('utf-8')


def call_api(url, data):
    """Call disvoice."""
    headers = {'Content-Type': 'application/json'}
    response = requests.post(url, data=json.dumps(data), headers=headers, timeout=30)
    return response.json()

def get_identifier(filename):
    keys_id = re.findall("\d+",os.path.splitext(os.path.basename(filename))[0])
    session_id = keys_id[1]
    trial_id = keys_id[2]
    return session_id, trial_id


