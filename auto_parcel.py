# auto_parcel.py
from flask import Flask, request, jsonify
from flask_cors import CORS
from shapely.geometry import Point, Polygon

app = Flask(__name__)
CORS(app)

# Örnek polygonlar - gerçek sistemde otomatik oluşturulacak
example_polygons = [
    {
        'parcel_id': 1,
        'owner': 'Otto Joe',
        'type': 'Tarla',
        'area': 500,
        'polygon': Polygon([
            (28.977, 41.007),
            (28.979, 41.007),
            (28.979, 41.009),
            (28.977, 41.009)
        ])
    }
]

@app.route('/api/getParcelAuto', methods=['GET'])
def get_parcel():
    lat = request.args.get('lat', type=float)
    lng = request.args.get('lng', type=float)
    
    if lat is None or lng is None:
        return jsonify({'error': 'lat ve lng gerekli'}), 400
    
    point = Point(lng, lat)
    
    for parcel in example_polygons:
        if parcel['polygon'].contains(point):
            return jsonify({
                'parcel_id': parcel['parcel_id'],
                'owner': parcel['owner'],
                'type': parcel['type'],
                'area': parcel['area']
            })
    
    return jsonify({'error': 'Bu noktada parsel bulunamadı'}), 404

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000)

