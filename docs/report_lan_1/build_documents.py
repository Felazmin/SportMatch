"""Build editable draw.io pages and readable report artifacts from local sources."""
from pathlib import Path
import base64
import html
import json
import math
import re
import shutil
import sqlite3
import textwrap
import urllib.parse
import xml.etree.ElementTree as ET
import zlib
from PIL import ImageFont
from diagram_layout import route_page, bridge_path, hits, rect

ROOT = Path(__file__).resolve().parent
OUT = ROOT / 'diagrams'
OUT.mkdir(exist_ok=True)
FONT = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 14)


def wrap(text, width, size=14):
    font = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', size)
    result = []
    for para in text.split('\n'):
        line = ''
        for word in para.split(' '):
            candidate = (line + ' ' + word).strip()
            if line and font.getlength(candidate) > width:
                result.append(line)
                line = word
            else:
                line = candidate
        result.append(line)
    return result


class Page:
    def __init__(self, code, title, subtitle, width=1120, height=900):
        self.code, self.title, self.subtitle = code, title, subtitle
        self.width, self.height = width, height
        self.nodes, self.edges = [], []
        self.next_node_id=2
        self.node(title, 28, 14, width-56, 42, 'title', size=23)
        self.node(subtitle, 28, 60, width-56, 48, 'subtitle', size=14)

    def node(self, text, x, y, w, h, kind='box', size=14, fill=None):
        n = dict(id=f'n{self.next_node_id}', text=text, x=x, y=y, w=w, h=h,
                 kind=kind, size=size, fill=fill)
        self.next_node_id+=1
        self.nodes.append(n)
        return n['id']

    def edge(self, source=None, target=None, label='', dashed=False, points=None,
             arrow=True, relation=False, anchors=None):
        self.edges.append(dict(source=source, target=target, label=label,
                               dashed=dashed, points=points, arrow=arrow, relation=relation,anchors=anchors))

    def xml(self):
        m = ET.Element('mxGraphModel', dx=str(self.width), dy=str(self.height),
                       grid='1', gridSize='10', page='1', pageScale='1',
                       pageWidth=str(self.width), pageHeight=str(self.height), math='0')
        root = ET.SubElement(m, 'root')
        ET.SubElement(root, 'mxCell', id='0')
        ET.SubElement(root, 'mxCell', id='1', parent='0')
        for n in self.nodes:
            k = n['kind']
            fill = n['fill'] or ('#e9f5ef' if k in ('table','class') else '#ffffff')
            style = (f'whiteSpace=wrap;html=0;fontFamily=Arial;fontSize={n["size"]};'
                     f'fontColor=#172b25;fillColor={fill};strokeColor=#60756d;rounded=0;spacing=10;')
            if k == 'actor': style += 'shape=umlActor;verticalLabelPosition=bottom;verticalAlign=top;'
            if k == 'oval': style += 'ellipse;'
            if k in ('title','subtitle','label'): style += 'text;strokeColor=none;fillColor=none;spacing=2;'
            if n.get('badge'): style += 'fillColor=#ffffff;fontStyle=1;'
            if n.get('white'): style += 'fillColor=#ffffff;'
            if k == 'title': style += 'fontStyle=1;align=left;'
            if k == 'subtitle': style += 'align=left;fontColor=#52635c;'
            if k in ('table','class'): style += 'align=left;verticalAlign=top;'
            if k == 'frame': style += 'fillColor=none;dashed=1;align=left;verticalAlign=top;'
            if k == 'fragment': style += 'fillColor=none;align=left;verticalAlign=top;'
            cell = ET.SubElement(root, 'mxCell', id=n['id'], value=n['text'],
                                 style=style, vertex='1', parent='1')
            ET.SubElement(cell, 'mxGeometry', x=str(n['x']), y=str(n['y']),
                          width=str(n['w']), height=str(n['h']), **{'as':'geometry'})
        for i, e in enumerate(self.edges):
            style = ('edgeStyle=orthogonalEdgeStyle;rounded=0;html=0;fontFamily=Arial;'
                     'fontSize=12;strokeColor=#527367;labelBackgroundColor=#ffffff;'
                     f'endArrow={"block" if e["arrow"] else "none"};endFill=0;jumpStyle=arc;jumpSize=9;')
            if e['dashed']: style += 'dashed=1;'
            if e['points']: style += 'edgeStyle=none;'
            if e['anchors']:
                ex,ey,ix,iy=e['anchors']
                style+=f'exitX={ex};exitY={ey};exitPerimeter=0;entryX={ix};entryY={iy};entryPerimeter=0;'
            attrs = dict(id=f'e{i}', value=e['label'], style=style, edge='1', parent='1')
            if e['source']: attrs['source'] = e['source']
            if e['target']: attrs['target'] = e['target']
            cell = ET.SubElement(root, 'mxCell', **attrs)
            g = ET.SubElement(cell, 'mxGeometry', relative='1', **{'as':'geometry'})
            if e['points']:
                for name, (x,y) in zip(('sourcePoint','targetPoint'), (e['points'][0],e['points'][-1])):
                    ET.SubElement(g, 'mxPoint', x=str(x), y=str(y), **{'as':name})
                if len(e['points'])>2:
                    array=ET.SubElement(g,'Array',**{'as':'points'})
                    for x,y in e['points'][1:-1]:ET.SubElement(array,'mxPoint',x=str(x),y=str(y))
        return m

    def svg(self):
        esc = html.escape
        parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{self.width}" height="{self.height}" viewBox="0 0 {self.width} {self.height}">',
                 '<defs><marker id="arrow" markerWidth="9" markerHeight="9" refX="8" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8" fill="none" stroke="#527367"/></marker></defs>',
                 '<rect width="100%" height="100%" fill="white"/>']
        lookup = {n['id']:n for n in self.nodes}
        # Edges first so connectors stay behind shapes.
        prior_segments=[]
        for e in self.edges:
            if e['points']:
                (x1,y1),(x2,y2) = e['points'][0],e['points'][-1]
                path=bridge_path(e['points'],prior_segments)
                prior_segments.extend(zip(e['points'],e['points'][1:]))
            else:
                a,b=lookup[e['source']],lookup[e['target']]
                ax,ay=a['x']+a['w']/2,a['y']+a['h']/2
                bx,by=b['x']+b['w']/2,b['y']+b['h']/2
                if abs(bx-ax)>abs(by-ay):
                    x1=ax+(a['w']/2 if bx>ax else -a['w']/2); y1=ay
                    x2=bx+(-b['w']/2 if bx>ax else b['w']/2); y2=by
                    mid=(x1+x2)/2
                    path=f'M{x1},{y1} L{mid},{y1} L{mid},{y2} L{x2},{y2}'
                else:
                    x1=ax; y1=ay+(a['h']/2 if by>ay else -a['h']/2)
                    x2=bx; y2=by+(-b['h']/2 if by>ay else b['h']/2)
                    mid=(y1+y2)/2
                    path=f'M{x1},{y1} L{x1},{mid} L{x2},{mid} L{x2},{y2}'
            dash=' stroke-dasharray="5 4"' if e['dashed'] else ''
            marker=' marker-end="url(#arrow)"' if e['arrow'] else ''
            parts.append(f'<path d="{path}" fill="none" stroke="#527367" stroke-width="1.5"{dash}{marker}/>')
            if e['label']:
                tx,ty=(x1+x2)/2,(y1+y2)/2-5
                lines=wrap(e['label'],180,12)
                for j,line in enumerate(lines):
                    parts.append(f'<text x="{tx}" y="{ty+j*15}" font-family="Arial" font-size="12" text-anchor="middle" fill="#27483b" stroke="white" stroke-width="4" paint-order="stroke">{esc(line)}</text>')
        for n in self.nodes:
            x,y,w,h,k=n['x'],n['y'],n['w'],n['h'],n['kind']
            if n.get('badge') or n.get('white'):
                parts.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="white"/>')
            fill=n['fill'] or ('#e9f5ef' if k in ('table','class') else '#ffffff')
            if k=='actor':
                cx=x+w/2
                parts.append(f'<g stroke="#27483b" fill="none" stroke-width="2"><circle cx="{cx}" cy="{y+14}" r="12"/><path d="M{cx},{y+26} v42 M{cx-23},{y+42} h46 M{cx},{y+68} l-22,27 M{cx},{y+68} l22,27"/></g>')
                lines=wrap(n['text'],w+35,n['size'])
                ty=y+114
            else:
                if k=='oval':
                    parts.append(f'<ellipse cx="{x+w/2}" cy="{y+h/2}" rx="{w/2}" ry="{h/2}" fill="{fill}" stroke="#60756d"/>')
                elif k not in ('title','subtitle','label'):
                    extra=' stroke-dasharray="5 4"' if k=='frame' else ''
                    parts.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{"none" if k in ("frame","fragment") else fill}" stroke="#60756d"{extra}/>')
                lines=wrap(n['text'],w-22,n['size'])
                lineheight=n['size']*1.32
                ty=y+19 if k in ('table','class','frame','fragment','title','subtitle') else y+(h-len(lines)*lineheight)/2+n['size']
            lineheight=n['size']*1.32
            if k not in ('actor','title','subtitle','label','frame'):
                assert len(lines)*lineheight+18<=h+1, (self.code,n['text'],len(lines),h)
            for j,line in enumerate(lines):
                left=k in ('table','class','frame','fragment','title','subtitle')
                tx=x+11 if left else x+w/2
                weight='bold' if k=='title' or (k in ('table','class') and j==0) else 'normal'
                parts.append(f'<text x="{tx}" y="{ty+j*lineheight}" font-family="Arial" font-size="{n["size"]}" font-weight="{weight}" text-anchor="{"start" if left else "middle"}" fill="#172b25">{esc(line)}</text>')
        parts.append('</svg>')
        return ''.join(parts)


pages=[]


def usecase(code,title,actor,items):
    p=Page(code,title,'Nguyên mẫu hiện tại • association không biểu diễn thứ tự thao tác',height=840)
    a=p.node(actor,35,350,125,140,'actor',16)
    p.node('Biên hệ thống SportMatch',200,110,880,690,'frame')
    for i,(name,detail) in enumerate(items):
        col,row=i%2,i//2
        excluded=name.startswith(('Không được','Chưa có'))
        n=p.node(name,240+col*425,160+row*150,365,110,'box' if excluded else 'oval',16,
                 fill='#fff5df' if excluded else None)
        if not excluded:p.edge(a,n,arrow=False)
        if detail:p.node(detail,240+col*425,273+row*150,365,32,'label',12)
    pages.append(p)


p=Page('UC00','Use case tổng quan','Bốn tác nhân nghiệp vụ; khách vãng lai chỉ xem công khai/đăng ký. Chi tiết xem UC01–UC04.',height=930)
actors=[p.node(n,25 if i<2 else 960,180+(i%2)*380,120,140,'actor',16)
        for i,n in enumerate(['Khách hàng','Chủ sân','Nhân viên','Admin'])]
p.node('Biên hệ thống SportMatch',190,115,720,760,'frame')
groups=[('Tìm sân, đặt lịch, thanh toán mẫu',[0]),('Lịch đặt, hủy, hoàn và đánh giá',[0,1,3]),
        ('Hồ sơ, lịch sân, giá và doanh thu',[1,3]),('Nhân viên, quyền và ca làm',[1,3]),
        ('Xem lịch, điểm danh, thu tại sân',[2]),('Hoạt động, giải đấu và cộng đồng',[0,1,3]),
        ('Kiểm duyệt bảy nhóm quản lý',[3])]
for i,(label,who) in enumerate(groups):
    n=p.node(label,275,145+i*100,550,72,'oval',16)
    for a in who:p.edge(actors[a],n,arrow=False)
pages.append(p)
usecase('UC01','Use case khách hàng','Khách hàng',[
    ('UC01 Đăng nhập và hồ sơ','FR01–FR02'),('UC02 Tìm sân và đặt lịch','FR03–FR06'),
    ('UC03 Gửi chứng từ thanh toán','FR07'),('UC04 Xem lịch và yêu cầu hủy','FR09–FR10'),
    ('UC12 Đăng ký giải đấu','FR22–FR23'),('UC14 Hội nhóm và diễn đàn','FR25–FR26'),
    ('UC15 Gửi đánh giá','FR12'),('UC16 Tài khoản và hỗ trợ','FR27 FR30')])
usecase('UC02','Use case chủ sân','Chủ sân',[
    ('UC06 Thêm sửa gửi hồ sơ','FR13–FR14'),('UC08 Lịch sân khóa giờ giá','FR16–FR17'),
    ('UC03 Duyệt chứng từ','FR08'),('UC05 Duyệt hủy ghi nhận hoàn','FR11'),
    ('UC09 Phân quyền nhân viên','FR18'),('UC11 Tạo gửi hoạt động','FR21'),
    ('UC13 Lịch đấu và kết quả','FR24'),('UC16 Khách hàng và doanh thu','FR28')])
usecase('UC03','Use case nhân viên','Nhân viên',[
    ('UC01 Đăng nhập nhân viên','Phiên riêng, nhân viên còn hoạt động'),('UC10 Xem lịch được giao','Cần schedule và đúng cơ sở'),
    ('UC10 Điểm danh','Cần attendance và đúng thời gian'),('UC10 Thu tại sân','Cần onsite; chỉ lịch đặt sân'),
    ('UC10 Xem ca của mình','Không xem ca của mọi người'),('Không được cấp quyền hoặc hoàn','Ranh giới quyền, không phải chức năng')])
usecase('UC04','Use case admin','Admin',[
    ('UC07 Quản lý sân và chủ sân','Duyệt / bổ sung / từ chối'),('UC16 Quản lý người dùng','FR29: khóa / mở theo chức năng hiện có'),
    ('UC15 Quản lý đánh giá','Giữ / ẩn có lý do'),('UC08 Quản lý loại sân và giá','Danh mục, đề xuất giá'),
    ('UC11 Quản lý hoạt động','Giao lưu và giải đấu'),('UC14 Quản lý hội nhóm','Kiểm duyệt hồ sơ nhóm'),
    ('UC16 Báo cáo hệ thống','Thu chi và dữ liệu nghiệp vụ'),('Chưa có ủy quyền admin con','Không đánh dấu đã triển khai')])


def sequence(code,title,participants,steps,notes):
    height=280+len(steps)*57+len(notes)*47
    p=Page(code,title,'Hiện trạng: gọi nội bộ Flutter, không có API server. Mũi tên đứt: trả kết quả hoặc lỗi.',width=1160,height=height)
    count=len(participants); xs=[100+i*(960/(count-1)) for i in range(count)]
    for x,name in zip(xs,participants):
        p.node(name,x-85,115,170,52,'box',14)
        p.edge(points=[(x,167),(x,220+len(steps)*57)],dashed=True,arrow=False)
    p.node('alt [kiểm tra hợp lệ]',20,175,1120,height-195,'fragment',12)
    for i,(src,dst,msg,response) in enumerate(steps):
        y=235+i*57
        x1,x2=xs[src],xs[dst]
        if src==dst:
            x2=x1+65
            p.edge(points=[(x1,y),(x2,y),(x2,y+12),(x1,y+12)],dashed=response)
        else:
            p.edge(points=[(x1,y),(x2,y)],dashed=response)
        width=max(210,abs(x2-x1)-20)
        p.node(f'{i+1}. {msg}',min(x1,x2)+(abs(x2-x1)-width)/2,y-40,width,38,'label',13)
        p.nodes[-1]['white']=True
    boundary=220+len(steps)*57
    p.edge(points=[(20,boundary),(1140,boundary)],arrow=False)
    p.node('else [có lỗi hoặc không đủ điều kiện tại bước tương ứng]',30,boundary+3,1080,26,'label',12)
    for i,note in enumerate(notes):
        p.node(note.replace('alt:','Điều kiện:'),40,boundary+35+i*47,1080,42,'box',13,fill='#fff5df')
    pages.append(p)


sequence('SQ01','Đặt sân và xác nhận thanh toán',
 ['Khách / Chủ sân','UI Flutter','DemoSession','SessionStore'],[
 (0,1,'Chọn giờ và xác nhận thông tin',False),(1,2,'reserve: quyền, lịch trùng, giá và policy',False),
 (2,1,'DemoBooking hoặc lỗi; snapshot hợp đồng',True),(1,2,'startTransfer(checkout: true)',False),
 (2,1,'Deadline tối đa 15 phút, thông tin chuyển khoản',True),
 (0,1,'Chọn ảnh thanh toán và thẻ sinh viên mẫu',False),(1,2,'saveProofDraft / saveStudentDraft; submitProof',False),
 (2,3,'Xếp hàng lưu snapshot JSON',False),(3,2,'Lưu thành công hoặc saveFailed',True),
 (2,1,'notifyListeners: pending, chưa xác nhận',True),
 (0,1,'Đăng nhập chủ sân, xem và quyết định',False),(1,2,'reviewPayment(approve / note)',False),
 (2,3,'Lưu trạng thái và ngày ghi nhận',False),(2,1,'approved hoặc rejected có lý do',True)],
 ['alt: trùng giờ / sai quyền / thiếu ảnh / quá hạn → trả lỗi, không chuyển approved.',
  'alt: lỗi ghi storage → UI cảnh báo chưa lưu; retrySave, không cam kết đã bền vững.'])
sequence('SQ02','Hết hạn checkout', ['Khách hàng','UI thanh toán','DemoSession','SessionStore'],[
 (0,1,'Mở thanh toán',False),(1,2,'Đọc deadline và expired(now)',False),
 (2,1,'Chờ chứng từ, bộ đếm theo deadline',True),(1,2,'Khi hết hạn: đọc lại trạng thái thực tế',False),
 (2,1,'expired chỉ cho awaitingProof / rejected',True),(1,0,'Popup hết hạn và hướng điều hướng',True),
 (0,1,'Thử gửi chứng từ sau hạn',False),(1,2,'submitProof kiểm tra lại thời gian',False),
 (2,1,'Từ chối gửi; không tự ghi nhận đã thanh toán',True)],
 ['alt: đã pending hoặc approved → không áp dụng nhánh hết hạn chờ ảnh.',
  'Store không có tác vụ tự hoàn tiền; UI popup không phải webhook ngân hàng.'])
sequence('SQ03','Yêu cầu hủy và ghi nhận hoàn', ['Khách / Chủ sân','UI hủy lịch','DemoSession','SessionStore'],[
 (0,1,'Mở yêu cầu hủy lịch',False),(1,2,'canRequestBookingCancellation; estimatedBookingRefund',False),
 (2,1,'alt còn hạn: form / quá hạn: lý do chặn',True),
 (0,1,'Nhập lý do, nơi nhận hoàn, chấp nhận phí',False),(1,2,'requestCancellation: kiểm tra lại hạn và giá',False),
 (2,3,'Lưu requested và thời điểm yêu cầu',False),(2,1,'Chờ phản hồi; lịch chưa hủy',True),
 (0,1,'Chủ sân đăng nhập và xử lý',False),(1,2,'reviewCancellation(approve / reject)',False),
 (2,1,'alt accepted: hủy + refund pending; rejected: giữ lịch',True),
 (0,1,'Ghi nhận chứng từ hoàn mẫu nếu có',False),(1,2,'recordWorkflowRefund',False),
 (2,3,'Lưu recorded, reference và proof',False),(2,1,'Trạng thái hoàn đã ghi nhận',True)],
 ['alt: quá hạn / đã điểm danh / sai chủ lịch / yêu cầu trùng → chặn, không tính phí mới.',
  'Tiền hoàn dựa policy snapshot và thời điểm yêu cầu; chưa thanh toán thì dự kiến hoàn bằng 0.'])
sequence('SQ04','Gửi sửa và duyệt hồ sơ cơ sở', ['Chủ sân / Admin','UI hồ sơ','DemoSession','SessionStore'],[
 (0,1,'Nhập hồ sơ, ảnh và giấy tờ mẫu',False),(1,2,'saveFacility; submitFacility',False),
 (2,3,'Lưu draft/pending và revision',False),(2,1,'Hiển thị Chờ duyệt',True),
 (0,1,'Sửa hồ sơ đang chờ',False),(1,2,'updatePendingFacility(expectedRevision)',False),
 (2,3,'Lưu draft mới, tăng revision; vẫn pending',False),
 (0,1,'Admin đăng nhập, mở bản mới nhất',False),(1,2,'reviewFacility: approve, reject, note, expectedRevision',False),
 (2,1,'alt revision cũ → yêu cầu mở lại',True),
 (2,3,'Duyệt: published=draft; nhánh khác: lý do',False),
 (2,1,'approved / supplement / rejected',True)],
 ['Yêu cầu bổ sung dùng state rejected + reviewDecision supplement trong code.',
  'Chỉ published được công khai; không sửa lời người gửi khi ra quyết định.'])
sequence('SQ05','Phân quyền và thao tác nhân viên', ['Chủ sân / NV','UI nhân viên','DemoSession','SessionStore'],[
 (0,1,'Chọn quyền/cơ sở và mật khẩu xác nhận',False),(1,2,'configureEmployeeAccess\n(expectedRevision)',False),
 (2,2,'Kiểm tra managerPassword, schedule phụ thuộc, scope',False),
 (2,3,'Lưu access và revision mới',False),
 (0,1,'Nhân viên đăng nhập trực tiếp',False),(1,2,'loginEmployee; employeeSchedule',False),
 (2,1,'Lịch/ca đúng phạm vi hoặc lỗi đăng nhập',True),
 (0,1,'Chọn điểm danh hoặc thu tại sân',False),(1,2,'employeeSetAttendance / employeeConfirmPayment',False),
 (2,2,'Kiểm tra quyền hiện hành, cơ sở, thời gian, trạng thái',False),
 (2,3,'Lưu kết quả và nhật ký',False),(2,1,'Thành công hoặc lỗi thiếu quyền',True)],
 ['alt: quyền đã thu hồi / NV ngừng / ngoài cơ sở → chặn cả khi còn phiên cũ.',
  'onsite chỉ thu lịch đặt sân; nhân viên không duyệt hoàn tiền hay cấp quyền.'])
sequence('SQ06','Đăng ký và thanh toán giải đấu', ['Khách hàng','UI giải đấu','DemoSession','SessionStore'],[
 (0,1,'Xem giải, nhập người đăng ký và đồng đội',False),(1,2,'joinEvent: thời gian, capacity, nhóm, vé',False),
 (2,1,'Vé với eventSnapshot hoặc lỗi',True),(0,1,'Chọn phương thức và bấm thanh toán',False),
 (1,2,'payTournamentDemo(ticket, method)',False),(2,2,'Ghi approved; simulatedGateway=true',False),
 (2,3,'Lưu vé, thanh toán và trạng thái',False),(2,1,'Mã đăng ký, xác nhận suất',True),
 (0,1,'Xem vé và lịch đấu',False),(1,2,'Đọc vé/fixtures theo tài khoản',False),
 (2,1,'Trả thông tin thuộc phạm vi',True)],
 ['Đây là thanh toán mô phỏng, không có PSP, webhook hoặc email thật.',
  'alt: hết chỗ / ngưng / hết hạn / vé không hợp lệ → không báo thành công.'])


db=sqlite3.connect(':memory:')
db.executescript((ROOT/'schema.sql').read_text(encoding='utf-8'))
tables=[r[0] for r in db.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")]
schema={t:dict(columns=list(db.execute(f'PRAGMA table_info("{t}")')),
               fks=list(db.execute(f'PRAGMA foreign_key_list("{t}")'))) for t in tables}
erd_groups=[
 ('ER01','ERD danh tính và nhân viên',['users','roles','user_roles','employee_profiles','employee_permissions','employee_facilities','employee_shifts','facilities','owner_verifications']),
 ('ER02','ERD cơ sở và bảng giá',['sports','court_types','facilities','facility_versions','courts','documents','tariff_proposals','tariff_bands','favorites']),
 ('ER03','ERD đặt sân và tài chính',['users','orders','bookings','payments','cancellation_requests','refunds','court_reservations','reviews','disputes']),
 ('ER04','ERD hoạt động và cộng đồng',['play_groups','group_memberships','group_join_requests','posts','events','event_occurrences','registrations','tournament_matches','orders']),
 ('ER05','ERD các chức năng bổ trợ',['users','documents','payment_methods','support_tickets','courses','enrollments','expenses','expense_shares','audit_entries']),
 ('ER06','ERD tin nhắn và chi trả',['users','chat_conversations','chat_participants','chat_messages','documents','payouts','payout_items','payments'])]
for code,title,names in erd_groups:
    p=Page(code,title,'THIẾT KẾ DB ĐỀ XUẤT • Bảng lặp là cùng thực thể. Mã R nối với danh sách quan hệ phía dưới; FK ngoài trang xem từ điển.',width=1460,height=1480)
    nodes={}
    for i,t in enumerate(names):
        cols=schema[t]['columns']; fks={r[3] for r in schema[t]['fks']}
        lines=[t]
        chosen=cols[:7]
        for c in chosen:
            key='PK ' if c[5] else 'FK ' if c[1] in fks else '   '
            lines.append(f'{key}{c[1]}: {c[2]}')
        if len(cols)>7: lines.append(f'… +{len(cols)-7} cột trong từ điển')
        nodes[t]=p.node('\n'.join(lines),70+(i%3)*460,140+(i//3)*310,340,225,'table',15)
    port_counts={};relations=[];label_positions=[]
    for child in names:
        for fk in schema[child]['fks']:
            parent=fk[2]
            if parent not in nodes:continue
            col=next(c for c in schema[child]['columns'] if c[1]==fk[3])
            optional=not col[3] and not col[5]
            unique=bool(col[5] and len([c for c in schema[child]['columns'] if c[5]])==1)
            for index in db.execute(f'PRAGMA index_list("{child}")'):
                if index[2] and not index[4]:
                    fields=[r[2] for r in db.execute(f'PRAGMA index_info("{index[1]}")')]
                    unique=unique or fields==[fk[3]]
            label=f'{"0..1" if optional else "1"} : {"0..1" if unique else "0..*"}'
            # Draw only one connector for a composite FK.
            if fk[1]!=0:continue
            ai,bi=names.index(parent),names.index(child)
            ac,ar=ai%3,ai//3;bc,br=bi%3,bi//3
            a=next(n for n in p.nodes if n['id']==nodes[parent])
            b=next(n for n in p.nodes if n['id']==nodes[child])
            direction=1 if bc>=ac else -1
            parent_side=1 if direction==1 else 0
            child_side=parent_side if ac==bc else 1-parent_side
            key=(parent,parent_side)
            count=port_counts.get(key,0);port_counts[key]=count+1
            offset=(count-1)*23
            y1=a['y']+a['h']/2+offset
            y2=b['y']+b['h']/2
            x1=a['x']+a['w']*parent_side;x2=b['x']+b['w']*child_side
            g1=x1+(32 if parent_side else -20)
            g2=x2+(32 if child_side else -20)
            if ar==br and abs(ac-bc)==1:
                route=[(x1,y1),(x2,y1),(x2,y2)]
                labelx=(x1+x2)/2
            elif abs(g1-g2)<65 or ac==bc:
                g=g1
                route=[(x1,y1),(g,y1),(g,y2),(x2,y2)]
                labelx=g
            else:
                gutter=120+ar*270 if ar==0 else 117+ar*270
                route=[(x1,y1),(g1,y1),(g1,gutter),(g2,gutter),(g2,y2),(x2,y2)]
                labelx=g1
            p.edge(nodes[parent],nodes[child],points=route,arrow=False,relation=True,
                   anchors=(parent_side,(y1-a['y'])/a['h'],child_side,.5))
            relation_id=f'R{len(relations)+1:02}'
            ly=y1-21
            while any(abs(labelx-lx)<32 and abs(ly-oy)<17 for lx,oy in label_positions):ly-=18
            label_positions.append((labelx,ly))
            p.node(relation_id,labelx-17,ly,34,20,'label',12)
            relations.append(f'{relation_id}  {parent}.{fk[4]} [{label.split(" : ")[0]}] → {child}.{fk[3]} [{label.split(" : ")[1]}]')
    p.node('Quan hệ khóa ngoại trong trang • Đối chiếu mã R và số lượng trong danh sách dưới đây',40,1080,1380,32,'subtitle',15)
    for i,relation in enumerate(relations):
        p.node(relation,40+(i%2)*710,1125+(i//2)*37,680,35,'label',14)
    pages.append(p)


p=Page('CL01','Class diagram lõi state và lưu trữ','LỚP HIỆN CÓ • Đường đứt là phụ thuộc hoặc implements, nhãn giải thích extension; thuộc tính/phương thức được rút gọn.',height=850)
app=p.node('MyApp\n+ session: DemoSession?\n+ build(): MaterialApp',35,150,300,135,'class')
ui=p.node('Các Screen / Widget\n+ session: DemoSession\n+ build(context)\n+ gọi nghiệp vụ và nghe thay đổi',35,410,300,170,'class')
session=p.node('DemoSession : ChangeNotifier\n- _store: SessionStore?\n- _bookings / _payments / _facilities\n+ initialize(), flush(), retrySave()\n+ reserve(), login(), logout()\n- _snapshot(), _restore()\n- _changed(), _queueSave()',410,235,360,220,'class')
store=p.node('«interface» SessionStore\n+ read(): Future<String?>\n+ write(value): Future<void>',835,150,250,145,'class')
secure=p.node('SecureSessionStore\n- FlutterSecureStorage\n+ read(), write()\nkey: nvh_demo_session_v1',835,405,250,170,'class')
ext=p.node('Các extension nghiệp vụ\nDemoManagement\nDemoFacilitiesSession\nDemoEmployeeAccessSession\nDemoWorkflowSession\npart of demo_session.dart',410,575,360,205,'class')
p.edge(app,session,'khởi tạo',dashed=True);p.edge(ui,session,'gọi / lắng nghe',dashed=True)
p.edge(session,store,'0..1 store',arrow=False);p.edge(secure,store,'implements',dashed=True)
p.edge(ext,session,'extension on, không phải service',dashed=True)
pages.append(p)
p=Page('CL02','Class diagram miền nghiệp vụ','LỚP HIỆN CÓ • Association theo ID hoặc collection logic, không phải mọi liên kết đều là object reference.',width=1380,height=950)
names=[
 ('DemoUser','name, identifier, role\nrole: player | owner | admin'),
 ('DemoBooking','id, owner, facilityId, court\nstart, hours, hourlyRates\ncancellationPolicy, attendance'),
 ('DemoPayment','bookingId, deadline, state\ncancellation, refund, proof\nreceivedAt, simulatedGateway'),
 ('DemoFacility','id, owner, state, revision\ndraft: FacilityProfile\npublished: FacilityProfile?'),
 ('FacilityProfile','name, address, sport, courts\nopenHour, closeHour, price\nphoto, legalProof, policy'),
 ('CancellationPolicy','thresholdHours, minimumHours\nearlyPercent, latePercent\nrefundAmount(), canRequest()'),
 ('DemoEmployeeAccess','password, permissions\nfacilityIds, revision'),
 ('DemoParticipation','id, owner, eventId, start\neventSnapshot, team, partner\nattendance, cancelled'),
 ('DemoActivity / DemoEvent','Activity: event, owner, state, revision\nEvent: kind, capacity, fee\nscheduledStart, durationMinutes')]
nodes={}
for i,(name,body) in enumerate(names):
    nodes[name]=p.node(name+'\n'+body,35+(i%3)*460,145+(i//3)*265,340,190,'class',14)
for a,b,label in [('DemoUser','DemoBooking','1 : 0..* theo owner'),('DemoBooking','DemoPayment','1 : 0..1 theo bookingId'),
                  ('DemoFacility','FacilityProfile','draft 1, published 0..1'),('DemoBooking','CancellationPolicy','1 policy snapshot'),
                  ('DemoUser','DemoParticipation','1 : 0..* theo owner'),('DemoParticipation','DemoActivity / DemoEvent','snapshot / eventId')]:
    p.edge(nodes[a],nodes[b],label,arrow=False)
pages.append(p)


p=Page('DP01','Deployment hiện tại','ĐÃ TRIỂN KHAI NGUYÊN MẪU • Không có API/DB server. Các phiên vai trò dùng cùng thiết bị khi demo.',height=800)
p.node('«device» Android emulator / điện thoại Android',35,130,700,570,'frame',16)
apk=p.node('«artifact» APK Flutter debug\nUI + DemoSession + mô hình\nAssets ảnh và font đóng gói',85,210,590,135,'box',17)
store=p.node('FlutterSecureStorage\nSnapshot JSON cục bộ\nKhông đồng bộ giữa các máy',85,465,275,150,'box',16)
native=p.node('Plugin thiết bị\nẢnh / PDF / mic / GPS\nTheo quyền Android',400,465,275,150,'box',16)
network=p.node('Dịch vụ bản đồ bên ngoài\nTile mạng, Nominatim\nPlatform geocoding',810,245,270,160,'box',16)
p.edge(apk,store,'read / write',arrow=False);p.edge(apk,native,'plugin API',arrow=False)
p.edge(apk,network,'HTTPS / Internet',arrow=False)
p.node('Chưa nghiệm thu điện thoại thật/iOS/web đầy đủ; không có ngân hàng, email hoặc chat server của đồ án.',790,500,300,130,'box',15,fill='#fff5df')
pages.append(p)
p=Page('DP02','Deployment backend dự kiến','THIẾT KẾ TƯƠNG LAI • Chưa nối vào Flutter. SQL bàn giao dùng SQLite để kiểm tra thiết kế quan hệ độc lập.',height=790)
client=p.node('«device» Flutter Android\nUI + repository / API client',35,285,260,135,'box',17)
api=p.node('«node» HTTPS API\nAuth + authorization\nBooking / finance transactions\nRevision + idempotency',420,235,300,200,'box',17)
dbnode=p.node('«database» DB quan hệ\nusers, facilities, orders…\nEngine máy chủ chưa chốt',830,130,260,160,'box',16)
files=p.node('«storage» Tệp riêng tư\nChứng từ / giấy tờ\nKiểm soát truy cập',830,365,260,150,'box',16)
external=p.node('«external» PSP / push / email\nSandbox, hợp đồng tích hợp\nChưa triển khai',420,580,300,135,'box',15,fill='#fff5df')
p.edge(client,api,'HTTPS + token',arrow=False);p.edge(api,dbnode,'giao dịch / FK',arrow=False)
p.edge(api,files,'metadata + quyền',arrow=False);p.edge(api,external,'tích hợp tương lai',dashed=True,arrow=False)
pages.append(p)


p=Page('UX01','Sitemap và luồng UI UX','Các mục cùng vai trò là nhánh độc lập, không phải thứ tự bắt buộc. Đây không phải sơ đồ phân quyền server.',width=1500,height=960)
root=p.node('Mở ứng dụng / chọn phiên đăng nhập',505,130,490,70,'box',18)
categories=[('Khách hàng',['Trang chủ / tìm sân / bản đồ','Chọn giờ → thông tin → thanh toán','Lịch đặt → chi tiết → hủy','Khám phá → giải → đăng ký → vé','Tài khoản / yêu thích / hỗ trợ']),
 ('Chủ sân',['Dashboard / cơ sở','Thêm / chỉnh sửa / chờ duyệt','Lịch / khóa giờ / bảng giá','Thanh toán / hủy / doanh thu','Nhân viên / quyền / hoạt động']),
 ('Nhân viên',['Không gian nhân viên','Lịch và ca được giao','Chi tiết trong phạm vi','Điểm danh nếu có quyền','Thu tại sân nếu có quyền']),
 ('Admin',['Tổng quan / báo cáo','Sân / chủ sân / người dùng','Đánh giá / loại sân','Hoạt động / hội nhóm','Hồ sơ → quyết định → lịch sử'])]
for i,(title,items) in enumerate(categories):
    x=20+i*370
    cat=p.node(title,x,280,275,65,'box',18,fill='#e9f5ef')
    sx=505+490*(i+1)/5;tx=x+137.5;lane=222+i*12
    p.edge(root,cat,points=[(sx,200),(sx,lane),(tx,lane),(tx,280)],anchors=((i+1)/5,1,.5,0))
    p.edges[-1]['locked']=True
    for j,item in enumerate(items):
        n=p.node(item,x,410+j*95,275,75,'box',14)
        sy=293+j*10;ty=447.5+j*95;track=x+295+j*12
        p.edge(cat,n,arrow=False,points=[(x+275,sy),(track,sy),(track,ty),(x+275,ty)],anchors=(1,(sy-280)/65,1,.5))
        p.edges[-1]['locked']=True
pages.append(p)


def states(code,title,rows,links,subtitle):
    p=Page(code,title,subtitle,width=1120,height=780)
    nodes={}
    for i,(name,text) in enumerate(rows):
        nodes[name]=p.node(name+'\n'+text,40+(i%3)*370,160+(i//3)*240,300,130,'box',16)
    for a,b,label in links:p.edge(nodes[a],nodes[b],label)
    pages.append(p)
states('ST01','Trạng thái thanh toán và hủy',[
 ('awaitingProof','Chờ ảnh chứng từ'),('pending','Đã gửi, chờ quản lý'),('approved','Đã xác nhận, có receivedAt'),
 ('rejected','Bị từ chối, có thể gửi lại'),('expired','Trạng thái suy ra từ deadline'),('cancellation / refund','requested → accepted/rejected\npending → recorded')],
 [('awaitingProof','pending','submitProof'),('pending','approved','review approve'),('pending','rejected','review reject'),
  ('rejected','pending','gửi lại khi còn hạn'),('awaitingProof','expired','deadline'),('rejected','expired','deadline')],
 'expired không phải enum lưu; chỉ áp dụng awaitingProof/rejected. Hủy và hoàn là hai trục trạng thái riêng, không phải payment state.')
states('ST02','Trạng thái hồ sơ cơ sở',[
 ('draft','Bản nháp'),('pending','Chờ admin kiểm tra'),('approved','Có bản published'),
 ('rejected','reviewDecision rejected'),('supplement','state rejected + decision supplement'),('suspended','Cờ ngưng độc lập với state')],
 [('draft','pending','gửi đủ hồ sơ'),('pending','approved','duyệt'),('pending','rejected','từ chối'),
  ('pending','supplement','yêu cầu bổ sung'),('rejected','pending','sửa/gửi lại'),('supplement','pending','sửa/gửi lại'),
  ('approved','suspended','ngưng nhận đặt')],
 'Sửa pending tăng revision và giữ pending. Sửa hồ sơ đã duyệt tạo nháp theo luồng hiện có; published không bị thay trước khi duyệt.')


def encode_link(xml):
    # draw.io #R format: encodeURIComponent -> raw DEFLATE -> base64.
    encoded=urllib.parse.quote(xml,safe="~()*!.'-").encode('ascii')
    compressor=zlib.compressobj(9,zlib.DEFLATED,-15)
    data=base64.b64encode(compressor.compress(encoded)+compressor.flush()).decode('ascii')
    assert urllib.parse.unquote(zlib.decompress(base64.b64decode(data),-15).decode())==xml
    return 'https://app.diagrams.net/?splash=0&ui=kennedy#R'+data


for p in pages:
    connected=[e for e in p.edges if e['source'] and e['target']]
    if not connected:continue
    legends=[]
    if p.code.startswith('ER'):
        p.nodes=[n for n in p.nodes if not re.fullmatch(r'R\d{2}',n['text'])]
        for i,e in enumerate(connected):e['label']=f'R{i+1:02}'
    else:
        for e in connected:
            if e['label']:
                code=f'E{len(legends)+1:02}'
                legends.append(f'{code}  {e["label"]}')
                e['label']=code
    route_page(p)
    # Place short relation keys beside a free segment, never on a shape or another line.
    segments=[(a,b,e) for e in p.edges if e['points'] for a,b in zip(e['points'],e['points'][1:])]
    for e in connected:
        label=e['label'];e['label']=''
        if not label:continue
        candidates=[]
        for a,b in zip(e['points'],e['points'][1:]):
            if a[1]==b[1] and abs(a[0]-b[0])>=40:
                for f in (.5,.25,.75):
                    x=a[0]+(b[0]-a[0])*f-17
                    candidates.extend([(x,a[1]-24),(x,a[1]+5)])
            elif a[0]==b[0] and abs(a[1]-b[1])>=26:
                for f in (.5,.25,.75):
                    y=a[1]+(b[1]-a[1])*f-10
                    candidates.extend([(a[0]+5,y),(a[0]-39,y)])
        for x,y in candidates:
            r=(x-2,y-2,x+36,y+22)
            if not (0<x and x+34<p.width and 110<y and y+20<p.height):continue
            if any(not (r[2]<=n['x'] or n['x']+n['w']<=r[0] or r[3]<=n['y'] or n['y']+n['h']<=r[1])
                   for n in p.nodes if n['kind'] not in ('frame','fragment')):continue
            if any(hits(a,b,r) for a,b,other in segments):continue
            p.node(label,x,y,34,20,'label',12)
            p.nodes[-1]['badge']=True
            break
        else:raise ValueError(f'No safe label position: {p.code} {label} {e["points"]}')
    if legends:
        y=p.height+10
        p.node('Chú giải đường nối',30,y,p.width-60,30,'subtitle',15)
        for i,label in enumerate(legends):p.node(label,30,y+42+i*30,p.width-60,28,'label',14)
        p.height=y+52+len(legends)*30

doc=ET.Element('mxfile',host='app.diagrams.net',modified='2026-10-10T00:00:00.000Z',
               agent='SportMatch report generator',version='24.7.17',type='device')
links=[]
for p in pages:
    model=p.xml()
    diagram=ET.SubElement(doc,'diagram',id=p.code,name=f'{p.code} {p.title}')
    diagram.append(model)
    single=ET.Element('mxfile',host='app.diagrams.net',type='device')
    d=ET.SubElement(single,'diagram',id=p.code,name=p.title);d.append(p.xml())
    sx=ET.tostring(single,encoding='unicode')
    url=encode_link(sx)
    (OUT/f'{p.code}.drawio').write_text(sx,encoding='utf-8')
    (OUT/f'{p.code}.svg').write_text(p.svg(),encoding='utf-8')
    links.append(dict(code=p.code,title=p.title,url=url))
fullxml=ET.tostring(doc,encoding='unicode')
(ROOT/'SportMatch_Lan1.drawio').write_text(fullxml,encoding='utf-8')
(ROOT/'drawio_links.json').write_text(json.dumps(links,ensure_ascii=False,indent=2),encoding='utf-8')


CSS='''
*{box-sizing:border-box}body{margin:0;color:#15251e;background:#eef2ef;font:16px/1.65 Arial,sans-serif;letter-spacing:0}
main{max-width:1020px;margin:28px auto;background:white;padding:52px 62px}
h1,h2,h3{color:#000;line-height:1.25;break-after:avoid}h1{font-size:30px;margin-top:0}h2{font-size:23px;margin-top:40px}h3{font-size:18px;margin-top:28px}
p{margin:10px 0 14px}a{color:#086749;overflow-wrap:anywhere}code{font:13px Consolas,monospace;overflow-wrap:anywhere}pre{white-space:pre-wrap;background:#f4f6f5;padding:15px;font-size:13px}
table{border-collapse:collapse;width:100%;font-size:13px;line-height:1.5;margin:15px 0 22px;table-layout:fixed}th,td{border:1px solid #d9d9d9;padding:9px 10px;vertical-align:middle;overflow-wrap:anywhere}th{background:#dcebe4;color:#000;text-align:left}tr:nth-child(even){background:#f7f9f8}thead{display:table-header-group}tr{break-inside:avoid}
.requirements th:nth-child(1){width:11%}.requirements th:nth-child(2){width:35%}.requirements th:nth-child(3){width:54%}.trace th:nth-child(1){width:12%}.trace th:nth-child(2){width:14%}.trace th:nth-child(3),.trace th:nth-child(4){width:29%}.trace th:nth-child(5){width:16%}.usecases th:nth-child(1){width:11%}.usecases th:nth-child(2){width:43%}.usecases th:nth-child(3){width:20%}.usecases th:nth-child(4){width:26%}
img{max-width:100%;height:auto}figure{margin:20px 0}figcaption{font-size:13px;color:#51635b}nav{border-bottom:1px solid #d9d9d9;padding-bottom:20px;margin-bottom:26px}nav a{display:inline-block;margin:3px 12px 3px 0}
.diagram{break-before:page;page:diagram;margin-top:35px}.diagram img{width:100%;max-height:680px;object-fit:contain;object-position:left top}.diagram p{font-size:13px}.gallery{display:flex;gap:24px;align-items:flex-start}.gallery figure{flex:1}.gallery img{max-height:650px;object-fit:contain}
.muted{color:#52635c;font-size:14px}.link-table td:first-child{width:80px}.link-table td:last-child{width:160px}
@media(max-width:700px){main{margin:0;padding:24px 18px}h1{font-size:25px}table{font-size:12px}th,td{padding:7px 5px}.gallery{flex-direction:column}}
@page{size:Letter;margin:18mm 17mm 20mm}@page diagram{size:A3 landscape;margin:15mm}@page sequence{size:A3 portrait;margin:15mm}
@media print{body{background:white;font-size:10.5pt;line-height:1.5}main{padding:0;margin:0;max-width:none}nav,.noprint{display:none}h1{font-size:23pt}h2{font-size:17pt}h3{font-size:13pt}table{font-size:9pt}a{color:#153f2f;text-decoration:none}h2{margin-top:24px}figure{break-inside:avoid}.diagram{margin:0;break-after:page}.diagram h2{font-size:17pt;margin:0 0 8px}.diagram p{margin:4px 0 12px}.diagram img{max-height:900px}.diagram.sequence{page:sequence}.diagram.sequence img{max-height:1340px}.gallery img{max-height:440px}}
'''


def inline(s):
    s=html.escape(s)
    s=re.sub(r'`([^`]+)`',r'<code>\1</code>',s)
    s=re.sub(r'\*\*([^*]+)\*\*',r'<strong>\1</strong>',s)
    s=re.sub(r'\b[a-z][a-z0-9]*(?:_[a-z0-9]+)+\b',lambda m:m[0].replace('_','_<wbr>'),s)
    return s


def markdown_to_html(text):
    # Small deterministic renderer for the controlled report syntax only.
    lines=text.splitlines(); result=[]; i=0
    while i<len(lines):
        s=lines[i]
        if not s.strip():i+=1;continue
        if s.startswith('```'):
            block=[];i+=1
            while i<len(lines) and not lines[i].startswith('```'):block.append(lines[i]);i+=1
            result.append('<pre>'+html.escape('\n'.join(block))+'</pre>');i+=1;continue
        if s.startswith('|'):
            rows=[]
            while i<len(lines) and lines[i].startswith('|'):
                row=[x.strip() for x in lines[i].strip('|').split('|')]
                if not all(re.fullmatch(r'[-: ]+',x or ' ') for x in row):rows.append(row)
                i+=1
            style='requirements' if rows[0][0]=='Mã' and len(rows[0])==3 else 'trace' if rows[0][0]=='Yêu cầu' and len(rows[0])==5 else 'usecases' if rows[0][0]=='Mã' and len(rows[0])==4 else ''
            result.append(f'<table class="{style}"><thead><tr>'+''.join('<th>'+inline(c)+'</th>' for c in rows[0])+'</tr></thead><tbody>')
            for row in rows[1:]:result.append('<tr>'+''.join('<td>'+inline(c)+'</td>' for c in row)+'</tr>')
            result.append('</tbody></table>');continue
        m=re.match(r'^(#{1,3}) (.+)',s)
        if m:
            level=len(m[1]);ident=re.sub(r'[^a-zA-Z0-9]+','-',m[2]).strip('-')
            result.append(f'<h{level} id="{ident}">{inline(m[2])}</h{level}>');i+=1;continue
        if re.match(r'^\d+\. ',s):
            result.append('<ol>')
            while i<len(lines) and re.match(r'^\d+\. ',lines[i]):
                result.append('<li>'+inline(re.sub(r'^\d+\. ','',lines[i]))+'</li>');i+=1
            result.append('</ol>');continue
        para=[s];i+=1
        while i<len(lines) and lines[i].strip() and not re.match(r'^(#|\||```|\d+\. )',lines[i]):para.append(lines[i]);i+=1
        result.append('<p>'+inline(' '.join(para))+'</p>')
    return '\n'.join(result)


def html_page(title,body):
    return '<!doctype html><html lang="vi"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>'+html.escape(title)+'</title><style>'+CSS+'</style><main>'+body+'</main></html>'


nav='<nav><a href="index.html">Bộ tài liệu</a><a href="BAO_CAO.html">Báo cáo</a><a href="drawio_links.html">Mở sơ đồ draw.io</a><a href="data_dictionary.html">Từ điển dữ liệu</a></nav>'
report_html=markdown_to_html((ROOT/'BAO_CAO.md').read_text(encoding='utf-8'))
chapters=re.findall(r'<h2 id="([^"]+)">([^<]+)</h2>',report_html)
toc='<section><h2>Mục lục</h2><ol>'+''.join(f'<li><a href="#{ident}">{re.sub(r"^\d+ ","",title)}</a></li>' for ident,title in chapters)+'</ol></section>'
first_section=report_html.find('<h2 ')
body=nav+report_html[:first_section]+toc+report_html[first_section:]
previews=ROOT/'evidence';previews.mkdir(exist_ok=True)
source=Path('D:/PTUDDD/test_do_an/build/previews')
captions={'natural-seed-emulator.png':'Dashboard chủ sân trên emulator, sau cập nhật dữ liệu.',
          'natural-venues-402.png':'Widget test 402px: danh sách chỉnh sửa sân; ảnh giả trong test.',
          'natural-venues-320.png':'Widget test 320px, text scale 2: chữ xuống dòng; ảnh giả trong test.'}
body+='<h2>Phụ lục ảnh minh chứng UI UX</h2><p>Ảnh đã có từ lần kiểm tra ứng dụng gần nhất, không phải ảnh tạo giả cho tài liệu.</p><div class="gallery">'
for filename,caption in captions.items():
    if (source/filename).exists():
        shutil.copy2(source/filename,previews/filename)
        body+=f'<figure><img src="evidence/{filename}" alt="{caption}"><figcaption>{caption}</figcaption></figure>'
body+='</div>'
for p in pages:
    kind='diagram sequence' if p.code.startswith(('SQ','ER')) else 'diagram'
    body+=f'<section class="{kind}"><h2>{p.code} {html.escape(p.title)}</h2><p>{html.escape(p.subtitle)}</p><img src="diagrams/{p.code}.svg" alt="{html.escape(p.title)}"></section>'
(ROOT/'BAO_CAO.html').write_text(html_page('Báo cáo đồ án lần 1 SportMatch',body),encoding='utf-8')
linkbody=nav+'<h1>Sơ đồ chỉnh sửa trong draw.io</h1><p>Các link dưới đây chứa bản sao dữ liệu sơ đồ trong URL. Không tải lên Drive, không cần xin quyền tài khoản. Chỉnh sửa rồi lưu file riêng; link cũ không tự cập nhật. File nhiều trang là bản đầy đủ để lưu trữ.</p><p><a href="SportMatch_Lan1.drawio" download>Tải bộ draw.io nhiều trang</a></p><table class="link-table"><thead><tr><th>Mã</th><th>Sơ đồ</th><th>Mở bản sao</th></tr></thead><tbody>'
for item in links:
    linkbody+=f'<tr><td>{item["code"]}</td><td><a href="diagrams/{item["code"]}.svg">{html.escape(item["title"])}</a></td><td><a target="_blank" rel="noopener" href="{html.escape(item["url"],quote=True)}">Mở draw.io</a></td></tr>'
linkbody+='</tbody></table>'
(ROOT/'drawio_links.html').write_text(html_page('Link draw.io SportMatch',linkbody),encoding='utf-8')
dictionary=nav+'<h1>Từ điển dữ liệu quan hệ đề xuất</h1><p>Sinh từ schema.sql bằng PRAGMA SQLite. PK ghép có thứ tự 1, 2; PK INTEGER có thể báo NOT NULL=0 trong PRAGMA nhưng vẫn là khóa duy nhất. Kiểu JSON dùng TEXT, cần validation ở ứng dụng. Thời gian UTC Unix giây, tiền INTEGER VND.</p>'
for t,info in schema.items():
    dictionary+=f'<h2>{t}</h2><table><thead><tr><th>Cột</th><th>Kiểu</th><th>NOT NULL</th><th>PK</th><th>Mặc định</th></tr></thead><tbody>'
    for c in info['columns']:
        dictionary+='<tr>'+''.join(f'<td>{html.escape(str(v if v is not None else ""))}</td>' for v in (c[1],c[2],c[3],c[5],c[4]))+'</tr>'
    dictionary+='</tbody></table>'
    for fk in info['fks']:dictionary+=f'<p><code>{fk[3]} → {fk[2]}.{fk[4]}</code>; ON UPDATE {fk[5]}, ON DELETE {fk[6]}.</p>'
(ROOT/'data_dictionary.html').write_text(html_page('Từ điển dữ liệu SportMatch',dictionary),encoding='utf-8')
index=nav+f'''<h1>Bộ tài liệu đồ án lần 1 SportMatch</h1>
<p>Bản phân tích thiết kế ngày 10/10/2026, dựa trên nguyên mẫu Flutter NVH Sports. Bao gồm URD, use case, sequence, ERD, class, deployment, UI/UX và kiểm thử. Tách rõ hiện trạng cục bộ với backend/DB dự kiến.</p>
<table><thead><tr><th>Tài liệu</th><th>Nội dung</th></tr></thead><tbody>
<tr><td><a href="BAO_CAO.html">Báo cáo HTML</a> / <a href="BAO_CAO.pdf">PDF</a> / <a href="BAO_CAO.md">Markdown</a></td><td>Báo cáo đầy đủ và {len(pages)} sơ đồ</td></tr>
<tr><td><a href="drawio_links.html">Link mở draw.io</a></td><td>Mỗi sơ đồ mở một bản sao chỉnh sửa được</td></tr>
<tr><td><a href="SportMatch_Lan1.drawio" download>File draw.io nhiều trang</a></td><td>{len(pages)} trang, shape và connector chỉnh sửa được</td></tr>
<tr><td><a href="schema.sql">SQL SQLite</a> / <a href="data_dictionary.html">Từ điển dữ liệu</a></td><td>{len(tables)} bảng đề xuất; chưa nối vào Flutter</td></tr>
<tr><td><a href="README.md">Hướng dẫn</a></td><td>Cách mở, kiểm tra, chỉnh sửa và chuẩn bị nộp</td></tr>
</tbody></table><h2>Lưu ý trước khi nộp</h2><p>Điền thông tin trường/nhóm; thống nhất tên app; xác nhận chính sách thẻ sinh viên; thử thiết bị thật. Không công bố đã có backend, thanh toán thật hoặc đồng bộ nhiều máy.</p>'''
(ROOT/'index.html').write_text(html_page('Bộ tài liệu SportMatch lần 1',index),encoding='utf-8')
manifest={'diagram_count':len(pages),'table_count':len(tables),'diagrams':[{k:i[k] for k in ('code','title')} for i in links],
          'source':'D:/PTUDDD/test_do_an','date':'2026-10-10','backend_implemented':False}
(ROOT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'diagrams':len(pages),'tables':len(tables),'output':str(ROOT)},ensure_ascii=True))
