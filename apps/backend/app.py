from flask import Flask, jsonify

app = Flask(__name__)

counter = 0

@app.route("/increment", methods=["POST"])
def increment():
    global counter
    counter += 1
    return jsonify({"value": counter})

@app.route("/decrement", methods=["POST"])
def decrement():
    global counter
    counter -= 1
    return jsonify({"value": counter})

@app.route("/value", methods=["GET"])
def value():
    return jsonify({"value": counter})

@app.route("/health", methods=["GET"])
def health():
    return "OK", 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
