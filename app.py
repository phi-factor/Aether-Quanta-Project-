from flask import Flask, jsonify, request, render_template, abort, flash, redirect, url_for
from kivy.app import App
from kivy.uix.widget import Widget
from kivy.network.urlrequest import UrlRequest
from pathlib import Path
import json
import cv2
from Crypto.Hash import SHA256
import numpy as np
from observer_module import observer
from utils.logger_config import configure_journal_logger
import os
from threading import Thread

# Re-import blueprints (adjust paths if needed)
from api import journal_api
from observer_api import observer_api

# ESQET Parameters
GRID_SIZE = 32
EMF_AMPLITUDE = 0.05
DIFFUSION_RATE = 0.1
SINK_STRENGTH = 0.3
HAWKING_NOISE = 0.01
HISTORY_LENGTH = 10
HAUNTING_STRENGTH = 0.4

# Flask App Initialization
app = Flask(__name__)
app.secret_key = os.urandom(24)  # For flash messages
app.config['UPLOAD_FOLDER'] = 'uploads'

# Register Blueprints
app.register_blueprint(journal_api)
app.register_blueprint(observer_api)

# Configure logger for errors
error_logger = configure_journal_logger()

# ESQET Image Analysis Function with Error Handling
def analyze_image(image_path):
    try:
        if not Path(image_path).is_file():
            raise FileNotFoundError(f"Image file not found: {image_path}")

        img = cv2.imread(image_path)
        if img is None:
            raise ValueError(f"Failed to decode image at {image_path}")

        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        sfield = cv2.resize(gray, (GRID_SIZE, GRID_SIZE)) / 255.0

        history = [sfield.copy()]
        for _ in range(30):
            emf = np.ones(GRID_SIZE) * EMF_AMPLITUDE * np.sin(np.linspace(0, 2*np.pi, GRID_SIZE))
            diffused = sfield + DIFFUSION_RATE * (
                np.roll(sfield, 1, axis=0) + np.roll(sfield, -1, axis=0) +
                np.roll(sfield, 1, axis=1) + np.roll(sfield, -1, axis=1) - 4 * sfield
            ) - SINK_STRENGTH * (np.array([15, 11]) == np.indices(sfield.shape).sum(axis=0)) + \
              emf.reshape(GRID_SIZE, 1) + np.random.normal(0, HAWKING_NOISE, sfield.shape)
            
            if np.any(diffused < 0) or np.any(np.isnan(diffused)):
                raise ValueError("Numerical instability in S_field evolution")

            sfield = np.clip(diffused, 0, 1)
            if len(history) >= HISTORY_LENGTH:
                history.pop(0)
            history.append(sfield.copy())

        edges = cv2.Canny((sfield * 255).astype(np.uint8), 100, 200)
        if edges is None:
            raise RuntimeError("Edge detection failed")
        density = np.sum(edges) / (GRID_SIZE * GRID_SIZE)
        if density < 0 or np.isnan(density):
            raise ValueError("Invalid entanglement density")

        coherence = density * 1000
        beautimus_rating = coherence * 0.975
        aeth_minted = max(1.0, coherence / 100)
        effective_cost = 100.0 / (coherence / 1000 if coherence > 0 else 1)
        if np.isnan(aeth_minted) or np.isnan(effective_cost):
            raise ValueError("Invalid AETH or cost calculation")

        identity_hash = SHA256.new(sfield.tobytes()).hexdigest()
        return {
            "coherence": float(coherence),
            "aeth_minted": float(aeth_minted),
            "effective_cost": float(effective_cost),
            "identity_hash": identity_hash
        }
    except FileNotFoundError as fnf:
        error_logger.error(json.dumps({"error": "FileError", "message": str(fnf), "path": str(image_path)}))
        return {"error": "File not found", "details": str(fnf)}, 404
    except ValueError as ve:
        error_logger.error(json.dumps({"error": "ValueError", "message": str(ve), "path": str(image_path)}))
        return {"error": "Processing error", "details": str(ve)}, 400
    except RuntimeError as re:
        error_logger.error(json.dumps({"error": "RuntimeError", "message": str(re), "path": str(image_path)}))
        return {"error": "Runtime failure", "details": str(re)}, 500
    except Exception as e:
        error_logger.error(json.dumps({"error": "UnexpectedError", "message": str(e), "path": str(image_path)}))
        return {"error": "Unexpected error", "details": str(e)}, 500

# Web Interface Route
@app.route('/', methods=['GET', 'POST'])
def upload_file():
    if request.method == 'POST':
        if 'image' not in request.files:
            flash('No image file provided.', category='error')
            return redirect(url_for('upload_file'))
        
        file = request.files['image']
        if file.filename == '':
            flash('No selected file.', category='error')
            return redirect(url_for('upload_file'))
        
        if file:
            filename = file.filename
            image_path = Path(app.config['UPLOAD_FOLDER']) / filename
            image_path.parent.mkdir(parents=True, exist_ok=True)
            try:
                file.save(image_path)
                result = analyze_image(str(image_path))
                if "error" in result:
                    flash(f"Analysis failed: {result[0]['details']}", category='error')
                    return redirect(url_for('upload_file'))
                
                # Log the analysis
                class DummyGlyph:
                    def __init__(self, glyph_id): self.glyph_id = "IMG_" + filename.split('.')[0]
                observer.log_analysis(DummyGlyph(filename), filename, "ANALYSIS_COMPLETE", result["coherence"], result["aeth_minted"])
                observer.log_signal(filename)
                observer.update_drift(result["coherence"])
                
                flash(f"Analysis complete! AETH minted: {result['aeth_minted']:.1f}", category='success')
                return render_template('result.html', result=result)
            except Exception as e:
                error_logger.error(json.dumps({"error": "UploadError", "message": str(e), "path": str(image_path)}))
                flash(f"Upload failed: {str(e)}", category='error')
                return redirect(url_for('upload_file'))
    
    return render_template('upload.html')

# API Endpoint for Image Analysis
@app.route('/api/analyze_image', methods=['POST'])
def analyze_image_endpoint():
    try:
        if 'image' not in request.files:
            abort(400, description="No image file provided")

        file = request.files['image']
        if file.filename == '':
            abort(400, description="No selected file")

        image_path = Path(app.config['UPLOAD_FOLDER']) / file.filename
        image_path.parent.mkdir(parents=True, exist_ok=True)

        try:
            file.save(image_path)
        except IOError as ioe:
            abort(500, description=f"Failed to save file: {str(ioe)}")

        result = analyze_image(str(image_path))
        if "error" in result:
            return jsonify(result[0]), result[1]

        class DummyGlyph:
            def __init__(self, glyph_id): self.glyph_id = "IMG_" + file.filename.split('.')[0]
        observer.log_analysis(DummyGlyph(file.filename), filename, "ANALYSIS_COMPLETE", result["coherence"], result["aeth_minted"])
        observer.log_signal(file.filename)
        observer.update_drift(result["coherence"])

        return jsonify({
            "message": "Image analyzed successfully",
            "coherence": result["coherence"],
            "aeth_minted": result["aeth_minted"],
            "effective_cost": result["effective_cost"],
            "identity_hash": result["identity_hash"]
        }), 200
    except Exception as e:
        error_logger.error(json.dumps({"error": "EndpointError", "message": str(e), "path": str(image_path) if 'image_path' in locals() else "N/A"}))
        abort(500, description=f"Endpoint failure: {str(e)}")

# Kivy App to run Flask
class AetherApp(App):
    def build(self):
        def run_flask():
            app.run(host='0.0.0.0', port=5000, debug=False, use_reloader=False)
        Thread(target=run_flask).start()
        import webbrowser
        webbrowser.open('http://0.0.0.0:5000')
        return Widget()

if __name__ == '__main__':
    AetherApp().run()
