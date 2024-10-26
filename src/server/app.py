import os
import sys
from flask import Flask, request, send_file
import shutil
import tarfile

app = Flask(__name__)
from logging.config import dictConfig

dictConfig({
    'version': 1,
    'formatters': {'default': {
        'format': '[%(asctime)s] %(levelname)s in %(module)s: %(message)s',
    }},
    'handlers': {'wsgi': {
        'class': 'logging.StreamHandler',
        'stream': 'ext://sys.stdout',
        'formatter': 'default'
    }},
    'root': {
        'level': 'INFO',
        'handlers': ['wsgi']
    }
})

request_file = "REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf"
response_file = "RESPONSE-999-EXCLUSION-RULES-AFTER-CRS.conf"

def get_rule_content(hostname, file):
    safe_dir = "/rules/"
    request_path = safe_dir + hostname
    if os.path.commonprefix((os.path.realpath(request_path),safe_dir)) != safe_dir: 
        return ""

    with open(request_path + "/" + file, 'r') as file:
        return file.read()

@app.route('/request')
def request_handler():
    hostname = request.args.get("hostname")

    default = get_rule_content("default", request_file)
    try:
        additions = get_rule_content(hostname, request_file)
    except:
        additions = ""

    return default + "\n" + additions

@app.route('/response')
def response_handler():
    hostname = request.args.get("hostname")

    default = get_rule_content("default", response_file)
    try:
        additions = get_rule_content(hostname, response_file)
    except:
        additions = ""

    return default + "\n" + additions

@app.route('/report_error', methods = ['POST'])
def report_handler():
    hostname = request.args.get("hostname")
    app.logger.info('Invalid report for ' + hostname + " Data: " + str(request.stream.read()))

    return "OK"

@app.route('/get_all_rules')
def get_all():
    rule_path = '/rules'
    tar_path = os.path.join(os.getcwd(), 'rules.tar')
    with tarfile.open(tar_path, "w") as tar:
        tar.add(rule_path, arcname=os.path.basename(rule_path))

    return send_file(tar_path, as_attachment=True)

if __name__ == "__main__":
    app.run() 
