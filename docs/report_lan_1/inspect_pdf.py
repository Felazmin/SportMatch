"""Make QA contact sheets and verify that report pages contain readable content."""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont
from pypdf import PdfReader

root=Path(__file__).resolve().parent
qa=root/'qa'
reader=PdfReader(root/'BAO_CAO.pdf')
pages=[]
for i,p in enumerate(reader.pages,1):
    text=p.extract_text() or ''
    assert '\ufffd' not in text, f'Replacement glyph on page {i}'
    assert len(text)>120, f'Unexpected blank/sparse page {i}'
    pages.append({'page':i,'characters':len(text),'width':float(p.mediabox.width),'height':float(p.mediabox.height)})
assert len(pages)>=40
files=sorted(qa.glob('pdf-reviewed-*.png')) or sorted(qa.glob('pdf-final-*.png'))
assert len(files)==len(pages), (len(files),len(pages))
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',16)
for offset in range(0,len(files),12):
    sheet=Image.new('RGB',(1200,1200),'#c8d0cb')
    draw=ImageDraw.Draw(sheet)
    for j,f in enumerate(files[offset:offset+12]):
        img=Image.open(f).convert('RGB');img.thumbnail((286,360))
        x=(j%4)*300+(300-img.width)//2;y=(j//4)*400+28
        sheet.paste(img,(x,y))
        draw.text(((j%4)*300+12,(j//4)*400+5),f'Trang {offset+j+1}',font=font,fill='black')
    sheet.save(qa/f'contact-{offset//12+1}.jpg',quality=90)
(qa/'pdf_review.json').write_text(json.dumps({'pages':len(pages),'page_details':pages},indent=2),encoding='utf-8')
print(f'{len(pages)} pages; contact sheets and structural PDF checks complete.')
codes=[d['code'] for d in json.loads((root/'manifest.json').read_text(encoding='utf-8'))['diagrams']]
for offset in range(0,len(codes),6):
    sheet=Image.new('RGB',(1600,1800),'#c8d0cb')
    draw=ImageDraw.Draw(sheet)
    for j,code in enumerate(codes[offset:offset+6]):
        img=Image.open(qa/f'{code}.png').convert('RGB');img.thumbnail((780,550))
        x=(j%2)*800+(800-img.width)//2;y=(j//2)*600+32
        sheet.paste(img,(x,y));draw.text(((j%2)*800+12,(j//2)*600+6),code,font=font,fill='black')
    sheet.save(qa/f'diagram-contact-{offset//6+1}.jpg',quality=92)
