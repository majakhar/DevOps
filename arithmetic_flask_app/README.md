Arithmetic Flask App

Simple Flask app that performs basic arithmetic operations via a web form and a JSON API.

Setup

1. Create a virtual environment (recommended):

   python3 -m venv venv
   source venv/bin/activate

2. Install requirements:

   pip install -r requirements.txt

3. Run the app:

   python app.py

Visit http://127.0.0.1:5000 in your browser.

API

POST /api/calc
Content-Type: application/json
Body: {"a": number, "b": number, "operation": "add|subtract|multiply|divide"}

Response: {"result": number, "operation": "...", "a": number, "b": number}
