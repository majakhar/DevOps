# Compatibility shim: ensure pkgutil.get_loader exists on Python builds that
# don't provide it (some Python 3.14 builds may omit it). Flask expects
# pkgutil.get_loader as a fallback when importlib can't find a package.
import pkgutil as _pkgutil
if not hasattr(_pkgutil, 'get_loader'):
    import importlib
    import importlib.util
    def _get_loader(name):
        try:
            spec = importlib.util.find_spec(name)
        except Exception:
            return None
        if spec is None:
            return None
        return spec.loader
    _pkgutil.get_loader = _get_loader

from flask import Flask, request, render_template, jsonify

app = Flask(__name__)

@app.route('/')
def index():
    return render_template('index.html')

def parse_number(value):
    try:
        return float(value), None
    except (ValueError, TypeError):
        return None, f"Invalid number: {value}"

@app.route('/calculate', methods=['POST'])
def calculate():
    op = request.form.get('operation')
    a_raw = request.form.get('a')
    b_raw = request.form.get('b')

    a, err = parse_number(a_raw)
    if err:
        return render_template('index.html', error=err)
    b, err = parse_number(b_raw)
    if err:
        return render_template('index.html', error=err)

    try:
        if op == 'add':
            result = a + b
        elif op == 'subtract':
            result = a - b
        elif op == 'multiply':
            result = a * b
        elif op == 'divide':
            if b == 0:
                return render_template('index.html', error='Division by zero')
            result = a / b
        else:
            return render_template('index.html', error='Unknown operation')
    except Exception as e:
        return render_template('index.html', error=str(e))

    return render_template('index.html', result=result, a=a, b=b, operation=op)

# JSON API endpoint
@app.route('/api/calc', methods=['POST'])
def api_calc():
    data = request.get_json() or {}
    op = data.get('operation')
    a_raw = data.get('a')
    b_raw = data.get('b')

    a, err = parse_number(a_raw)
    if err:
        return jsonify({'error': err}), 400
    b, err = parse_number(b_raw)
    if err:
        return jsonify({'error': err}), 400

    try:
        if op == 'add':
            result = a + b
        elif op == 'subtract':
            result = a - b
        elif op == 'multiply':
            result = a * b
        elif op == 'divide':
            if b == 0:
                return jsonify({'error': 'Division by zero'}), 400
            result = a / b
        else:
            return jsonify({'error': 'Unknown operation'}), 400
    except Exception as e:
        return jsonify({'error': str(e)}), 500

    return jsonify({'result': result, 'operation': op, 'a': a, 'b': b})

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=8083)
