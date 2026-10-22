# Thông báo SQLite và nhắc giờ chơi

Cập nhật: 20/10/2026. Chỉ triển khai hai mục: hộp thông báo lưu bằng SQLite và
nhắc lịch chơi đã xác nhận. Không bổ sung chức năng xuất phiếu PDF.

## Phạm vi và nền tảng

- Android/iOS: hộp thông báo SQLite và thông báo cục bộ đã lên lịch.
- Windows/Linux: hộp thông báo SQLite qua FFI; chưa bật thông báo hệ thống.
- macOS: hộp thông báo qua sqflite; chưa bật thông báo hệ thống.
- Web: chưa hỗ trợ cơ sở dữ liệu SQLite này. Các chức năng cũ vẫn giữ nguyên;
  cần chạy bản ứng dụng cài đặt để dùng hai chức năng mới.
- Lịch đặt vẫn lưu bằng SessionStore hiện có. Chỉ thông báo, trạng thái đã đọc,
  cấu hình nhắc và trạng thái đối chiếu lịch đặt nằm trong SQLite.
- Đây là local notification, không phải push notification. Chủ sân xác nhận trên
  một máy không tự gửi thông báo sang điện thoại khác. Ở bản demo, khách đăng
  nhập lại trên cùng ứng dụng để nhận trạng thái được cập nhật.
- Chưa tích hợp nhắc cho vé social, giải đấu hay ca làm nhân viên ở đợt này.

## Cách mở và dùng

1. Dừng hẳn ứng dụng đang chạy, chạy `flutter pub get` rồi chạy lại bằng
   `flutter run`. Có plugin native mới nên chỉ hot reload là chưa đủ.
2. Đăng nhập khách hàng, vào **Khám phá → biểu tượng chuông Thông báo**.
3. Tab **Tất cả** chứa thông báo xác nhận, đổi/hủy lịch và các nhắc đã đến giờ.
4. Tab **Chưa đọc** chỉ tính các thông báo đã đến giờ, không tính nhắc tương lai.
5. Bấm biểu tượng dấu kiểm để đánh dấu đã đọc; nút trên thanh tiêu đề đánh dấu
   toàn bộ thông báo đã đến giờ. Nút thùng rác yêu cầu xác nhận trước khi xóa.
6. Chạm thông báo để mở đúng chi tiết lịch đặt. Ứng dụng kiểm tra lại tài khoản
   trước khi mở và không cho đọc thông báo của tài khoản khác.
7. Vào biểu tượng bánh răng, bật **Nhắc trước giờ chơi**, chấp nhận quyền hệ
   thống và chọn 1, 15, 30 hoặc 60 phút. Mặc định nhắc hệ thống đang tắt.
8. Tab **Lịch nhắc** liệt kê nhắc tương lai; xóa tại đây hủy riêng lịch nhắc đó,
   không hủy lịch đặt sân.

## Tình huống kiểm thử thủ công

1. Khách đặt một lịch tương lai, gửi chứng từ mẫu.
2. Đăng xuất khách, vào chủ sân xác nhận thanh toán, đăng nhập lại khách trên
   cùng ứng dụng. Hộp thông báo có thông báo xác nhận lịch.
3. Bật nhắc trước giờ chơi. Lịch phải đã xác nhận, chưa hủy, chưa check-in và
   mốc `giờ bắt đầu - số phút nhắc` phải còn ở tương lai. Ví dụ giờ chơi 19:00,
   nhắc 15 phút thì lên lịch lúc 18:45; bật lúc 18:50 không tạo nhắc quá khứ.
4. Kiểm tra tab **Lịch nhắc**, đưa ứng dụng về nền và chờ đến mốc nhắc trên
   điện thoại Android/iOS đã cho phép thông báo.
5. Chạm thông báo hệ thống: mở đúng chi tiết lịch; số điện thoại, tên sân và dữ
   liệu tài khoản không được đưa vào nội dung hiển thị trên màn hình khóa.
6. Chủ sân đổi giờ/sân con rồi khách đăng nhập lại: hủy nhắc cũ, tạo nhắc mới và
   có thông báo đổi lịch.
7. Khách yêu cầu hủy: tạm dừng nhắc. Yêu cầu bị từ chối thì được khôi phục;
   được duyệt thì không nhắc nữa, giữ lịch sử thông báo.
8. Đăng xuất: hủy nhắc đang lên lịch trên thiết bị và ẩn nội dung ngay. Đăng
   nhập lại đúng khách: đọc lại dữ liệu SQLite và dựng lại các nhắc hợp lệ.
9. Tắt/mở ứng dụng bình thường không hủy nhắc đã lên lịch. Đóng rồi mở lại
   vẫn giữ thông báo đã đọc và không khôi phục thông báo người dùng đã xóa.
10. Từ chối quyền: hộp thông báo vẫn dùng được, công tắc nhắc trở về tắt và có
    cảnh báo. Cấp quyền trong cài đặt thiết bị rồi bật lại để thử tiếp.

Android dùng `inexactAllowWhileIdle`, không xin quyền báo thức chính xác,
full-screen intent hoặc foreground service. Hệ điều hành có thể trì hoãn nhắc,
nhất là chế độ tiết kiệm pin, ứng dụng bị force-stop hoặc một số ROM. Chưa cam
kết thông báo đến đúng từng giây. Với iOS chỉ lên lịch 60 nhắc gần nhất; ứng dụng
đối chiếu lại khi mở/khôi phục và định kỳ khi còn đang chạy.

## Cơ sở dữ liệu

Tên file: `sportmatch_notifications.db`, nằm trong vùng dữ liệu riêng của ứng
dụng; Windows/Linux dùng Application Support. Không ghi vào thư mục assets.

| Bảng | Mục đích |
|---|---|
| notifications | Người nhận, mã lịch, loại, nội dung, thời điểm tạo/nhắc, đã đọc, đã xóa |
| reminder_preferences | Cấu hình bật/tắt và số phút nhắc theo từng khách |
| booking_notice_states | Trạng thái/phiên bản lịch đã đối chiếu để tránh thông báo trùng |

Mọi truy vấn đọc/sửa/xóa đều kèm người nhận và dùng tham số SQL. Reconcile chạy
trong transaction. Ràng buộc UNIQUE(owner,eventKey) chống trùng. Xóa dùng cờ
deleted để việc đồng bộ lại không làm thông báo đã xóa xuất hiện lại. SQLite
này không chứa mật khẩu, tài khoản ngân hàng, ảnh chứng từ hoặc toàn bộ phiên.
Đây chưa phải cơ sở dữ liệu mã hóa; không đưa thêm thông tin nhạy cảm vào thông báo.

## Mã nguồn

- `lib/notifications/notification_store.dart`: SQLite, bảng dữ liệu, CRUD, transaction.
- `lib/notifications/notification_center.dart`: đối chiếu lịch đã xác nhận, phân
  tách tài khoản, cài đặt, chống lịch trùng, hủy/đổi nhắc và xử lý lỗi.
- `lib/notifications/reminder_gateway.dart`: quyền, timezone Việt Nam, API plugin.
- `lib/notifications/notification_database_*.dart`: chọn SQLite mobile/desktop.
- `lib/screens/notification_inbox_screen.dart`: hộp thông báo, đọc/xóa, cài đặt.
- `lib/main.dart`: khởi tạo, xử lý chạm thông báo và đối chiếu khi quay lại app.
- `test/notifications_test.dart`: SQLite thật qua FFI và bộ lập lịch giả.
- `test/notifications_widget_test.dart`: thao tác và ảnh chụp mobile/desktop.
- `test/reminder_gateway_test.dart`: kiểm tra lời gọi Android qua mock MethodChannel.

Tài liệu API đối chiếu:
- https://pub.dev/packages/flutter_local_notifications/versions/22.3.1
- https://docs.flutter.dev/cookbook/persistence/sqlite
- https://pub.dev/packages/sqflite_common_ffi

## Kiểm tra trên máy phát triển

Đã chạy kiểm thử SQLite thực qua FFI, kiểm thử bộ điều phối với lịch nhắc giả,
kiểm thử giao diện và mock MethodChannel Android. Đã chụp/kiểm tra giao diện ở
320 px với chữ 2x, 402 px và desktop. Không có điện thoại/giả lập Android kết nối.
Lệnh dựng APK đang bị môi trường Java/Gradle chặn với lỗi
`java.io.IOException: Unable to establish loopback connection`, kể cả khi thử IPv4.
Vì vậy chưa xác nhận APK hay việc hiện thông báo trên điện thoại thật.
Biên dịch bundle Dart không thay thế kiểm thử thiết bị.
