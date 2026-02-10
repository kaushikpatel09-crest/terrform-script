import os
import requests
from flask import Flask, render_template, redirect, url_for

app = Flask(__name__)

BE_BASE_URL = os.environ.get("BE_BASE_URL")

@app.route("/")
def index():
    res = requests.get(f"{BE_BASE_URL}/value")
    value = res.json()["value"]
    return render_template("index.html", value=value)

@app.route("/inc", methods=["POST"])
def increment():
    requests.post(f"{BE_BASE_URL}/increment")
    return redirect(url_for("index"))

@app.route("/dec", methods=["POST"])
def decrement():
    requests.post(f"{BE_BASE_URL}/decrement")
    return redirect(url_for("index"))

@app.route("/health", methods=["GET"])
def health():
    return "OK", 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=3000)
