"""Executable checks for the proposed SQL and editable diagram package."""
from pathlib import Path
import base64
import json
import sqlite3
import unittest
import urllib.parse
import xml.etree.ElementTree as ET
import zlib

ROOT=Path(__file__).resolve().parent


class SchemaTests(unittest.TestCase):
    def setUp(self):
        self.db=sqlite3.connect(':memory:')
        self.db.executescript((ROOT/'schema.sql').read_text(encoding='utf-8'))
        for i,name in enumerate(['Chủ sân mẫu','Minh Phát','Admin mẫu','Nhân viên mẫu','Chủ sân khác','Tấn Đạt'],1):
            self.db.execute('INSERT INTO users(id,display_name,identifier,password_hash,created_at) VALUES(?,?,?,?,0)',
                            (i,name,f'user{i}@example.test','not-a-real-hash-for-tests-only'))
        self.db.executescript('''
        INSERT INTO sports VALUES(1,'Cầu lông');
        INSERT INTO court_types(id,sport_id,name,state) VALUES(1,1,'Cầu lông tiêu chuẩn','approved');
        INSERT INTO facilities(id,owner_id,created_at,updated_at) VALUES(1,1,0,0),(2,5,0,0);
        INSERT INTO facility_versions(id,facility_id,version_no,name,address,district_label,city,court_type_id,
          court_count,open_minute,close_minute,hourly_price_vnd,contact_phone,representative,cancellation_policy_json,created_at)
          VALUES(1,1,1,'Cơ sở mẫu A','Địa chỉ mẫu','Khu vực mẫu','TP.HCM',1,2,360,1320,100000,'0000000000','Người mẫu','{}',0),
                (2,2,1,'Cơ sở mẫu B','Địa chỉ mẫu','Khu vực mẫu','TP.HCM',1,1,360,1320,100000,'0000000000','Người mẫu','{}',0);
        UPDATE facilities SET published_version_id=id;
        INSERT INTO courts VALUES(1,1,1,1),(2,1,2,1),(3,2,1,1);
        INSERT INTO employee_profiles(id,user_id,owner_id,employee_code) VALUES(1,4,1,'NV-TEST');
        INSERT INTO events(id,organizer_id,facility_id,title,kind,description,rules,state)
          VALUES(1,1,1,'Giải mẫu','tournament','Mô phỏng','Mô phỏng','approved');
        INSERT INTO event_occurrences VALUES(1,1,10000,20000,2,150000,0),(2,1,30000,40000,8,150000,0);
        INSERT INTO orders(id,code,customer_id,kind,amount_vnd,created_at)
          VALUES(10,'B10',2,'booking',100000,0),(20,'B20',6,'booking',100000,0),
                (11,'R11',2,'registration',150000,0),(12,'R12',6,'registration',150000,0),
                (13,'R13',2,'registration',150000,0),(14,'R14',6,'registration',150000,0);
        INSERT INTO bookings(order_id,court_id,starts_at,ends_at,contact_name,contact_phone,venue_snapshot_json,hourly_rates_json,cancellation_policy_json,attendance)
          VALUES(10,1,1000,4600,'Minh Phát','0000000000','{}','[100000]','{}','pending'),
                (20,2,1000,4600,'Tấn Đạt','0000000000','{}','[100000]','{}','completed');
        INSERT INTO registrations(order_id,occurrence_id,event_snapshot_json) VALUES(11,1,'{}'),(12,1,'{}'),(13,2,'{}'),(14,2,'{}');
        INSERT INTO documents(id,uploaded_by,kind,storage_uri,mime_type,byte_size,created_at)
          VALUES(1,1,'refund','test://sample','image/png',10,0);
        ''')

    def tearDown(self):
        self.db.close()

    def fails(self,sql,args=()):
        with self.assertRaises(sqlite3.IntegrityError):self.db.execute(sql,args)

    def reservation(self,i,start,end,court=1):
        self.db.execute("INSERT INTO court_reservations(id,court_id,kind,starts_at,ends_at) VALUES(?,?,'manual',?,?)",(i,court,start,end))

    def match(self,i,start=11000,end=12800,court=1,a=11,b=12,occ=1):
        self.db.execute("INSERT INTO tournament_matches(id,occurrence_id,team_a_order_id,team_b_order_id,court_id,starts_at,ends_at,state) VALUES(?,?,?,?,?,?,?,'scheduled')",(i,occ,a,b,court,start,end))

    def test_01_schema_integrity(self):
        self.assertEqual(self.db.execute('PRAGMA foreign_keys').fetchone()[0],1)
        self.assertEqual(self.db.execute('PRAGMA foreign_key_check').fetchall(),[])
        self.assertEqual(self.db.execute('PRAGMA integrity_check').fetchone()[0],'ok')
        self.assertEqual(self.db.execute("SELECT count(*) FROM sqlite_master WHERE type='table'").fetchone()[0],45)

    def test_02_identifier_unique(self):
        self.fails("INSERT INTO users(display_name,identifier,password_hash,created_at) VALUES('Tên mẫu','user1@example.test','long-test-placeholder-hash',0)")

    def test_03_foreign_key(self):
        self.fails('INSERT INTO favorites VALUES(999,1)')

    def test_04_publish_same_facility(self):
        self.fails('UPDATE facilities SET published_version_id=2 WHERE id=1')

    def test_05_published_version_cannot_move(self):
        self.fails('UPDATE facility_versions SET facility_id=2 WHERE id=1')

    def test_06_employee_scope_insert(self):
        self.db.execute('INSERT INTO employee_facilities VALUES(1,1)')
        self.fails('INSERT INTO employee_facilities VALUES(1,2)')

    def test_07_employee_scope_update(self):
        self.db.execute('INSERT INTO employee_facilities VALUES(1,1)')
        self.fails('UPDATE employee_facilities SET facility_id=2 WHERE employee_id=1')

    def test_08_reservation_overlap_insert(self):
        self.reservation(1,1000,4600)
        self.fails("INSERT INTO court_reservations(id,court_id,kind,starts_at,ends_at) VALUES(2,1,'manual',4000,5000)")

    def test_09_adjacent_allowed(self):
        self.reservation(1,1000,4600);self.reservation(2,4600,8200)

    def test_10_other_court_allowed(self):
        self.reservation(1,1000,4600);self.reservation(2,1000,4600,court=2)

    def test_11_reservation_overlap_update(self):
        self.reservation(1,1000,4600);self.reservation(2,4600,8200)
        self.fails('UPDATE court_reservations SET starts_at=4000 WHERE id=2')

    def test_12_booking_reservation_matches(self):
        self.fails("INSERT INTO court_reservations(id,court_id,booking_order_id,kind,starts_at,ends_at) VALUES(1,2,10,'booking',1000,4600)")

    def test_13_event_allocation_matches(self):
        self.fails("INSERT INTO court_reservations(id,court_id,occurrence_id,kind,starts_at,ends_at) VALUES(1,3,1,'event',10000,20000)")

    def test_14_reschedule_guard(self):
        self.db.execute("INSERT INTO court_reservations(id,court_id,booking_order_id,kind,starts_at,ends_at) VALUES(1,1,10,'booking',1000,4600)")
        self.fails('UPDATE bookings SET starts_at=2000 WHERE order_id=10')

    def test_15_cancel_releases(self):
        self.db.execute("INSERT INTO court_reservations(id,court_id,booking_order_id,kind,starts_at,ends_at) VALUES(1,1,10,'booking',1000,4600)")
        self.db.execute('UPDATE orders SET cancelled=1 WHERE id=10')
        self.assertEqual(self.db.execute('SELECT active FROM court_reservations').fetchone()[0],0)

    def test_16_no_reactivation(self):
        self.db.execute('UPDATE orders SET cancelled=1 WHERE id=10')
        self.fails('UPDATE orders SET cancelled=0 WHERE id=10')

    def test_17_booking_order_type(self):
        self.fails("INSERT INTO bookings(order_id,court_id,starts_at,ends_at,contact_name,contact_phone,venue_snapshot_json,hourly_rates_json,cancellation_policy_json) VALUES(11,1,1,2,'Mẫu','000','{}','[]','{}')")

    def test_18_registration_order_type(self):
        self.fails("INSERT INTO registrations(order_id,occurrence_id,event_snapshot_json) VALUES(10,2,'{}')")

    def test_19_capacity_insert(self):
        self.db.execute("INSERT INTO orders(id,code,customer_id,kind,amount_vnd,created_at) VALUES(15,'R15',2,'registration',100000,0)")
        self.fails("INSERT INTO registrations(order_id,occurrence_id,event_snapshot_json) VALUES(15,1,'{}')")

    def test_20_capacity_update(self):
        self.fails('UPDATE registrations SET quantity=2 WHERE order_id=11')

    def test_21_capacity_cancelled_not_counted(self):
        self.db.execute('UPDATE orders SET cancelled=1 WHERE id=11')
        self.db.execute("INSERT INTO orders(id,code,customer_id,kind,amount_vnd,created_at) VALUES(15,'R15',2,'registration',100000,0)")
        self.db.execute("INSERT INTO registrations(order_id,occurrence_id,event_snapshot_json) VALUES(15,1,'{}')")

    def test_22_approved_requires_receipt_date(self):
        self.fails("INSERT INTO payments(order_id,state,deadline) VALUES(10,'approved',100)")

    def test_23_pending_no_receipt_date(self):
        self.fails("INSERT INTO payments(order_id,state,deadline,received_at) VALUES(10,'pending',100,20)")

    def test_24_pending_cancellation_unique(self):
        q="INSERT INTO cancellation_requests(order_id,requested_by,requested_at,reason,state,estimated_refund_vnd,destination_json) VALUES(10,2,0,'Lý do mẫu','requested',95000,'{}')"
        self.db.execute(q);self.fails(q)

    def test_25_refund_requires_proof(self):
        self.db.execute("INSERT INTO cancellation_requests(id,order_id,requested_by,requested_at,reason,state,estimated_refund_vnd,destination_json) VALUES(1,10,2,0,'Lý do mẫu','accepted',95000,'{}')")
        self.fails("INSERT INTO refunds(cancellation_id,amount_vnd,state,reference,recorded_at) VALUES(1,95000,'recorded','DEMO',10)")

    def test_26_review_ownership_and_completed(self):
        self.fails("INSERT INTO reviews(booking_order_id,author_id,stars,content,created_at) VALUES(20,2,5,'Mẫu',0)")
        self.fails("INSERT INTO reviews(booking_order_id,author_id,stars,content,created_at) VALUES(10,2,5,'Mẫu',0)")
        self.db.execute("INSERT INTO reviews(booking_order_id,author_id,stars,content,created_at) VALUES(20,6,5,'Mẫu',0)")

    def test_27_review_duplicate(self):
        q="INSERT INTO reviews(booking_order_id,author_id,stars,content,created_at) VALUES(20,6,5,'Mẫu',0)"
        self.db.execute(q);self.fails(q)

    def test_28_match_participant_scope(self):
        self.fails("INSERT INTO tournament_matches(occurrence_id,team_a_order_id,team_b_order_id,court_id,starts_at,ends_at,state) VALUES(1,11,13,1,11000,12800,'scheduled')")

    def test_29_match_overlap(self):
        self.match(1)
        self.fails("INSERT INTO tournament_matches(occurrence_id,team_a_order_id,team_b_order_id,court_id,starts_at,ends_at,state) VALUES(1,11,12,2,11500,13300,'scheduled')")

    def test_30_match_update_overlap(self):
        self.match(1);self.match(2,13000,14800)
        self.fails('UPDATE tournament_matches SET starts_at=12000 WHERE id=2')

    def test_31_match_score_no_tie(self):
        self.match(1)
        self.fails("UPDATE tournament_matches SET state='completed',score_a=21,score_b=21 WHERE id=1")

    def test_32_payment_method_rules(self):
        self.db.execute("INSERT INTO payment_methods(user_id,provider,last_four,is_default) VALUES(2,'Mẫu','1234',1)")
        self.fails("INSERT INTO payment_methods(user_id,provider,last_four,is_default) VALUES(2,'Mẫu','5678',1)")
        self.fails("INSERT INTO payment_methods(user_id,provider,last_four) VALUES(2,'Mẫu','12ab')")

    def test_33_chat_sender_membership(self):
        self.db.execute('INSERT INTO chat_conversations VALUES(1,0)')
        self.db.execute('INSERT INTO chat_participants VALUES(1,2,NULL)')
        self.fails("INSERT INTO chat_messages(conversation_id,sender_id,kind,body,created_at) VALUES(1,6,'text','Mẫu',0)")

    def test_34_order_kind_immutable(self):
        self.fails("UPDATE orders SET kind='registration' WHERE id=10")


class DiagramTests(unittest.TestCase):
    def test_35_xml_native_cells_and_edges(self):
        doc=ET.parse(ROOT/'SportMatch_Lan1.drawio').getroot()
        self.assertEqual(len(doc.findall('diagram')),24)
        for d in doc.findall('diagram'):
            cells=d.findall('mxGraphModel/root/mxCell')
            ids=[c.attrib['id'] for c in cells]
            self.assertEqual(len(ids),len(set(ids)))
            self.assertTrue(any(c.get('vertex')=='1' for c in cells))
            for c in cells:
                for key in ('source','target'):
                    if c.get(key):self.assertIn(c.get(key),ids)

    def test_36_drawio_url_roundtrip(self):
        links=json.loads((ROOT/'drawio_links.json').read_text(encoding='utf-8'))
        self.assertEqual(len(links),24)
        for link in links:
            payload=link['url'].split('#R',1)[1]
            xml=urllib.parse.unquote(zlib.decompress(base64.b64decode(payload),-15).decode())
            self.assertEqual(xml,(ROOT/'diagrams'/f'{link["code"]}.drawio').read_text(encoding='utf-8'))
            ET.fromstring(xml)

    def test_37_svg_and_geometry(self):
        for f in (ROOT/'diagrams').glob('*.svg'):ET.parse(f)
        doc=ET.parse(ROOT/'SportMatch_Lan1.drawio')
        for d in doc.getroot().findall('diagram'):
            m=d.find('mxGraphModel');w=float(m.get('pageWidth'));h=float(m.get('pageHeight'))
            for c in m.findall('root/mxCell'):
                if c.get('vertex')!='1':continue
                g=c.find('mxGeometry');x=float(g.get('x'));y=float(g.get('y'))
                self.assertGreaterEqual(x,0);self.assertGreaterEqual(y,0)
                self.assertLessEqual(x+float(g.get('width')),w)
                self.assertLessEqual(y+float(g.get('height')),h)


if __name__=='__main__':
    suite=unittest.defaultTestLoader.loadTestsFromModule(__import__(__name__))
    result=unittest.TextTestRunner(verbosity=2).run(suite)
    summary={'scope':'SQL reference design and draw.io artifacts, NOT full Flutter test suite',
             'tests_run':result.testsRun,'failures':len(result.failures),'errors':len(result.errors),
             'passed':result.wasSuccessful()}
    (ROOT/'validation_results.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
    raise SystemExit(0 if result.wasSuccessful() else 1)
