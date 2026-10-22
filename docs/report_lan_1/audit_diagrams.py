"""Check connector/shape collisions and shared line segments in exported draw.io XML."""
from pathlib import Path
import json
import xml.etree.ElementTree as ET
from diagram_layout import hits, interaction

ROOT = Path(__file__).resolve().parent
doc = ET.parse(ROOT/'SportMatch_Lan1.drawio').getroot()
issues = []
review = []
for diagram in doc.findall('diagram'):
    code = diagram.get('id')
    cells = diagram.findall('mxGraphModel/root/mxCell')
    nodes = {}
    for c in cells:
        if c.get('vertex') != '1':
            continue
        style = c.get('style', '')
        frame = 'fillColor=none;dashed=1;' in style
        if 'fillColor=none;align=left;verticalAlign=top;' in style and not frame:
            continue
        g = c.find('mxGeometry')
        x,y,w,h = (float(g.get(k)) for k in ('x','y','width','height'))
        if frame:h=32
        nodes[c.get('id')] = (x,y,x+w,y+h)
    segments = []
    for c in cells:
        if c.get('edge') != '1' or not c.get('source'):
            continue
        g = c.find('mxGeometry')
        points = [g.find("mxPoint[@as='sourcePoint']")]+g.findall('Array/mxPoint')+[g.find("mxPoint[@as='targetPoint']")]
        if any(p is None for p in points):
            issues.append((code,c.get('id'),'missing explicit route'))
            continue
        points = [(float(p.get('x')),float(p.get('y'))) for p in points]
        for a,b in zip(points,points[1:]):
            if a[0] != b[0] and a[1] != b[1]:
                issues.append((code,c.get('id'),'non-orthogonal segment'))
            for nid,r in nodes.items():
                if nid not in (c.get('source'),c.get('target')) and hits(a,b,r):
                    issues.append((code,c.get('id'),'line through node',nid))
            for x,y,edge in segments:
                if edge != c.get('id') and interaction(a,b,x,y) >= 100000:
                    issues.append((code,c.get('id'),'shared line segment',edge,a,b,x,y))
            segments.append((a,b,c.get('id')))
    review.append({'page':code,'routed_segments':len(segments)})
result = {'pages':len(review),'issues':issues,'details':review,
          'note':'Sequence lifelines/messages intersect intentionally; connected diagram edges are checked here. Crossings use arc bridges.'}
(ROOT/'diagram_review.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'pages':len(review),'issues':len(issues)},ensure_ascii=False))
for issue in issues[:20]:print(issue)
raise SystemExit(bool(issues))
