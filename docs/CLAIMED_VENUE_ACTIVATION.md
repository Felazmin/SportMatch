# Hướng dẫn demo: nhận quản lý sân OSM và mở nhận lịch

Cập nhật: 20/10/2026. Chỉ kiểm thử trong bản demo trên cùng một thiết bị/cùng
kho dữ liệu SessionStore. Chưa có backend đồng bộ giữa nhiều điện thoại;
không xác minh quyền sở hữu thực tế, không chuyển tiền thật hoặc dùng giấy tờ thật.

## Tài khoản dùng thử

| Vai trò | Tài khoản | Mật khẩu mặc định |
|---|---|---|
| Chủ sân | owner@nvh.demo | Demo1234 |
| Admin | admin@nvh.demo | Demo1234 |
| Khách hàng | 0901234567 | Demo1234 |

Nếu đã đổi mật khẩu, dùng mật khẩu hiện tại. Không xóa dữ liệu ứng dụng giữa
các lần đổi vai trò. Đăng xuất rồi đăng nhập lại trên cùng ứng dụng.

## 1. Chủ sân gửi yêu cầu quản lý

Vào **Sân của tôi → Nhận quản lý sân có sẵn → Sân có sẵn**, tìm **Pickleball 426**.
Mở sân, nhập người đại diện, số điện thoại, căn cứ quản lý (20–1.000 ký tự), chọn
ảnh minh chứng mẫu JPG/PNG không quá 400 KB rồi gửi yêu cầu.
Nếu sân đã có hồ sơ được duyệt, chuyển đến bước 3; không tạo yêu cầu mới.

Kết quả: **Chờ duyệt quyền quản lý**. Khách vẫn chỉ xem thông tin sân, chưa đặt được.

## 2. Admin duyệt quyền quản lý

Đăng xuất chủ sân, đăng nhập Admin. Vào **Duyệt → Quyền quản lý sân**, mở đúng
hồ sơ, kiểm tra tên, vị trí và minh chứng. Nhập mật khẩu Admin rồi bấm duyệt.
Nếu từ chối, cần nhập lý do và chủ sân có thể bổ sung/gửi lại.

Kết quả: **Đã duyệt quyền quản lý**. Việc này chưa mở đặt sân.

## 3. Chủ sân cấu hình hồ sơ vận hành

Đăng nhập lại chủ sân. Vào danh sách yêu cầu quản lý, mở hồ sơ vừa duyệt và
bấm **Cấu hình sân để nhận lịch**. Tên, địa chỉ có sẵn, môn chơi và thông tin
liên hệ được điền trước để kiểm tra; địa chỉ còn thiếu phải tự bổ sung.

Nhập số sân con, giờ mở/đóng cửa, giá cơ bản mỗi giờ; chọn ảnh sân và tài liệu
mẫu. Điền ngân hàng, chủ tài khoản, số tài khoản **mô phỏng**. Không lấy giá
tham khảo OSM làm giá chính thức một cách tự động.

Dữ liệu gợi ý để kiểm thử, không phải giá hoặc tài khoản thật của Pickleball 426:

| Trường | Giá trị thử nghiệm |
|---|---|
| Tên cơ sở | Pickleball 426 |
| Địa chỉ | 16/15 Bình Lợi |
| Tỉnh/thành phố | TP. Hồ Chí Minh |
| Quận/huyện/khu vực | Bình Lợi Trung |
| Môn thể thao | Pickleball |
| Người đại diện | Nguyễn Văn Hùng |
| Điện thoại | 0901234567 |
| Số sân | 2 |
| Giờ mở cửa – đóng cửa | 06:00 – 22:00 |
| Giá cơ bản | 160000 |
| Ngân hàng | Ngân hàng mô phỏng |
| Chủ tài khoản | NGUYEN VAN HUNG |
| Số tài khoản | 0000000000 |

Bấm **Gửi yêu cầu duyệt sân**. Có thể lưu bản nháp để bổ sung sau; bản nháp
không xuất hiện như một sân nhận đặt lịch. Khi hồ sơ đã tạo, nút ở yêu cầu quản lý
đổi thành **Mở hồ sơ vận hành**, không tạo thêm một cơ sở trùng.

## 4. Admin duyệt hồ sơ vận hành

Đăng nhập Admin, mở mục duyệt hồ sơ sân/cơ sở (khác mục quyền quản lý ở bước 2).
Kiểm tra mã OSM liên kết, số sân, giờ mở cửa, giá, ảnh, giấy tờ mẫu và tài khoản
nhận tiền mô phỏng, rồi duyệt hồ sơ.

Kết quả: sân mở nhận lịch trong bản demo, vẫn một địa điểm trên danh sách/bản đồ.
Không duyệt hoặc yêu cầu bổ sung thì sân chưa nhận lịch.

## 5. Khách hàng đặt lịch

Đăng nhập khách hàng, tìm **Pickleball 426**, mở chi tiết và bấm **Đặt sân →
Đặt lịch theo sân**. Chọn ngày tương lai, Sân 1 hoặc Sân 2, giờ trong khoảng mở
cửa và số giờ, rồi tiếp tục nhập/xác nhận thông tin.

Giá phải theo cấu hình của chủ sân (ví dụ thử nghiệm 160.000 đồng/giờ), không
phải giá tham khảo trên trang thứ ba. Tại bước chuyển khoản, giao diện ghi rõ mô
phỏng và che số tài khoản. Chỉ tải ảnh thử nghiệm; không thực hiện giao dịch thật.

Lịch dùng mã cơ sở riêng nên không chặn sân chính hoặc sân của cơ sở khác.
Thử đặt trùng cùng sân/cùng giờ sẽ bị chặn; sân con khác vẫn đặt được nếu trống.

## 6. Kiểm tra thêm

- Lưu sân yêu thích trước khi duyệt, kiểm tra vẫn còn sau khi mở nhận lịch.
- Đóng/mở lại app: quyền quản lý, hồ sơ, lịch và cấu hình nhận tiền vẫn còn.
- Chủ sân sửa hồ sơ đã công bố: bản cũ vẫn áp dụng đến khi bản sửa được duyệt.
- Admin tạm ngưng: chặn lịch mới, giữ lịch cũ và thông tin nhận tiền đã chốt.
- Thử thiếu tài khoản nhận tiền: không gửi hồ sơ vận hành đi duyệt được.
- Thử duyệt quyền quản lý nhưng chưa duyệt hồ sơ vận hành: khách chưa đặt được.
- Muốn giá theo khung giờ: chủ sân mở **Sân của tôi → Bảng giá** của cơ sở,
  gửi đề xuất rồi Admin duyệt. Khung không có giá riêng dùng giá cơ bản.

## Mã nguồn chính

- `lib/demo/demo_facilities.dart`: hồ sơ vận hành, liên kết nguồn OSM, ngân hàng.
- `lib/auth/demo_facilities_session.dart`: quyền tạo hồ sơ và điều kiện công bố.
- `lib/auth/demo_operations_session.dart`: ghép dữ liệu, giữ mã địa điểm và giá.
- `lib/screens/venue_claims_screen.dart`: nút cấu hình sau duyệt quyền quản lý.
- `lib/screens/facilities_screen.dart`: biểu mẫu cấu hình và gửi duyệt.
- `lib/booking/demo_booking.dart`: lưu cấu hình nhận tiền tại thời điểm đặt.
- `test/claimed_venue_activation_test.dart`: kiểm thử nghiệp vụ và lưu dữ liệu.
- `test/claimed_venue_activation_widget_test.dart`: kiểm thử thao tác giao diện.
