"""Verify documented identifiers against this project's Flutter sources and text encoding."""
from pathlib import Path
import json
import re
import unicodedata

ROOT = Path(__file__).resolve().parent
PROJECT = Path('D:/PTUDDD/test_do_an')
checks = {
    'lib/auth/demo_session.dart': ['class DemoSession', 'class DemoUser', 'reserve(', 'retrySave('],
    'lib/auth/demo_management.dart': ['extension DemoManagement', 'startTransfer(', 'saveProofDraft(', 'saveStudentDraft(', 'submitProof(', 'reviewPayment(', 'requestCancellation(', 'reviewCancellation(', 'canRequestBookingCancellation(', 'estimatedBookingRefund('],
    'lib/auth/demo_facilities_session.dart': ['saveFacility(', 'submitFacility(', 'updatePendingFacility(', 'reviewFacility(', 'expectedRevision', 'bool reject = false'],
    'lib/auth/demo_employee_access_session.dart': ['configureEmployeeAccess(', 'loginEmployee(', 'employeeSchedule', 'employeeSetAttendance(', 'employeeConfirmPayment('],
    'lib/auth/demo_workflow_session.dart': ['payTournamentDemo(', 'recordWorkflowRefund('],
    'lib/demo/demo_activities.dart': ['class DemoActivity', 'final DemoEvent event', 'final int revision'],
    'lib/demo/demo_events.dart': ['class DemoEvent', 'scheduledStart', 'durationMinutes'],
    'lib/demo/demo_employee_access.dart': ['class DemoEmployeeAccess', 'facilityIds', 'permissions'],
    'lib/demo/demo_cancellation_policy.dart': ['class CancellationPolicy', 'canRequest(', 'refundAmount('],
    'lib/demo/demo_finance.dart': ['enum DemoRole { player, owner, admin }', 'enum DemoPaymentState { awaitingProof, pending, rejected, approved }'],
}
verified = []
for relative, identifiers in checks.items():
    source = (PROJECT/relative).read_text(encoding='utf-8')
    for identifier in identifiers:
        assert identifier in source, (relative,identifier)
        verified.append({'file':relative,'identifier':identifier})
files = [ROOT/'BAO_CAO.md', ROOT/'README.md', ROOT/'build_documents.py']
files += list((ROOT/'diagrams').glob('*.drawio'))
for f in files:
    value = f.read_text(encoding='utf-8')
    assert '\ufffd' not in value, f
    assert not any(token in value for token in ('Ã¡','á»','áº')), f
    assert unicodedata.normalize('NFC',value) == value, f
all_dart = {p.name for p in (PROJECT/'lib').rglob('*.dart')}
for name in re.findall(r'`([^`/\\]+\.dart)`',(ROOT/'BAO_CAO.md').read_text(encoding='utf-8')):
    assert name in all_dart, name
summary = {'source':str(PROJECT),'identifiers_checked':len(verified),
           'utf8_nfc_files_checked':len(files),'passed':True,'details':verified,
           'note':'Identifier and encoding checks complement manual review; they do not prove every business rule or replace Flutter tests.'}
(ROOT/'source_review.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
print(f'{len(verified)} source identifiers and {len(files)} UTF-8/NFC files checked.')
