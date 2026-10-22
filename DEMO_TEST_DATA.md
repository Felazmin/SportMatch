# Dữ liệu kiểm thử bốn vai trò

Bộ mẫu v2 tự nạp một lần khi mở ứng dụng sau cập nhật. Dữ liệu chỉ lưu cục bộ;
không phát sinh giao dịch thật, không gửi email và không thay thế backend.

## Tài khoản

Mật khẩu khởi tạo: `Demo1234`. Tài khoản đã đổi mật khẩu tiếp tục dùng mật khẩu đã đổi.

| Vai trò / Họ tên | Đăng nhập | Phạm vi |
| --- | --- | --- |
| Khách hàng chính: Văn Hùng | `0901234567` hoặc `demo@nvh.vn` | Lịch đặt, thanh toán, hủy, đánh giá, cộng đồng |
| Nguyễn Minh Anh | `0909000011` | Lịch và vé tham gia riêng |
| Nguyễn Quốc Bảo | `0909000012` | Lịch sử và đánh giá riêng |
| Trần Hoàng Nam | `0909000013` | Tài khoản mẫu bị khóa; admin có thể mở khóa |
| Minh Phát | `0909000014` | Một lịch sắp tới, một lịch hoàn thành |
| Tấn Đạt | `0909000015` | Một lịch sắp tới, một lịch hoàn thành |
| Chủ sân: Nguyễn Văn Hùng | `owner@nvh.demo` | Các chức năng chủ sân hiện có |
| Admin: Trần Thu Hà | `admin@nvh.demo` | Duyệt hồ sơ, kiểm duyệt, báo cáo |
| Quản lý sân: Trần Minh Hoàng | `0909000001` | Xem lịch, điểm danh, thu tại sân |
| Nhân viên: Lê Thảo Linh | `0909000002` | Chỉ xem lịch và ca làm |

Nhân viên vào **Tài khoản → Không gian nhân viên**, không cần chủ sân tạo thêm.
Mã NS cấp theo bộ đếm hiện tại, không cố định NS0001. Quyền chỉ áp dụng cho sân
chính và các cơ sở đã duyệt do bộ mẫu tạo, không tự cấp quyền trên cơ sở cũ.

## Tình huống Có Sẵn

Trên bản cài mới, bộ mẫu gồm:
- 5 hồ sơ cơ sở: 2 đã duyệt, 1 chờ duyệt, 1 cần bổ sung, 1 bản nháp.
- 25 lịch đặt, tính cả 2 lịch demo ban đầu: chờ minh chứng, chờ duyệt thanh toán,
  bị từ chối, đã xác nhận, hết hạn, yêu cầu hủy, từ chối hủy, chờ/đã ghi nhận
  hoàn tiền, thu tại sân, chưa tạo thanh toán, hoàn thành và vắng mặt.
- 2 nhân viên, 8 ca làm: ngày nạp dữ liệu và 3 ngày tiếp theo.
- 6 hoạt động, 4 vé tham gia, 1 trận đấu và 2 khoảng giữ sân.
- 5 loại sân, 5 hội nhóm theo các trạng thái; yêu cầu vào nhóm chờ/đã duyệt.
- 3 bài viết của 3 người dùng khác nhau trên bản cài mới; một bài đã ẩn.
- 2 đánh giá, trong đó một đánh giá đã ẩn; một khiếu nại có phản hồi chủ sân.
- Hồ sơ xác minh chủ sân và bảng giá cơ sở chờ duyệt.
- Lịch sử doanh thu; tài khoản nhận tiền giả; hồ sơ chi trả chờ, đã ghi nhận và bị từ chối.
- Sân yêu thích, phương thức thanh toán chỉ lưu 4 số cuối, lịch lớp học,
  yêu cầu hỗ trợ và khoản chia chi phí.

Ngày tính theo ngày nạp lần đầu. Không tự đổi ngày sau mỗi lần đăng nhập.
Nếu trùng lịch cũ, bộ nạp tìm ngày trống thay vì di chuyển lịch của bạn.
Điểm danh vẫn tuân thủ mốc 30 phút trước giờ chơi. Kiểm thử tự động dùng đồng hồ
giả lập để kiểm tra hết hạn thanh toán và điều kiện hủy.

## Bảo Toàn Dữ Liệu

- Tình huống và câu chữ: `lib/demo/demo_seed_data.dart`.
- Bộ nạp, liên kết và nâng cấp dữ liệu: `lib/auth/demo_seed_session.dart`.
- Chứng từ có cảnh báo DEMO: `lib/demo/demo_seed_assets.dart`.
- Trạng thái sau thao tác lưu riêng bằng `SecureSessionStore`, không ghi vào source.
- V2 nâng cấp dữ liệu v1, không tạo lại danh mục, không đổi ID, giá, lịch hay quyền.
- Chỉ sửa câu chữ mẫu cũ khớp chính xác; giữ các giá trị bạn đã tự chỉnh sửa.
- Tài khoản/số điện thoại trùng được giữ nguyên, không ghi đè mật khẩu hoặc tự cấp quyền.
- Không kích hoạt lại nhân viên đã ngừng hay đặt lại quyết định duyệt, hủy, khóa tài khoản.
- Kiểm tra toàn bộ snapshot trước khi áp dụng; lỗi nạp không ghi đè dữ liệu trên đĩa.
- Lỗi lưu hiển thị qua trạng thái lưu hiện có và cho phép thử lại.
- Danh mục đầy thì bỏ qua phần thêm vượt giới hạn, không xóa dữ liệu cũ.

## Tên Sân Tham Khảo

Đối chiếu ngày 10/10/2026. Khu vực dùng cách gọi quen thuộc của nguồn tham khảo,
không khẳng định đây là tên đơn vị hành chính hiện tại.

| Sân | Địa chỉ tham khảo | Nguồn |
| --- | --- | --- |
| Sân cầu lông Phú Thọ | 219 Lý Thường Kiệt | [Decathlon](https://www.decathlon.vn/blog/san-cau-long-phu-tho/) |
| Pickoland Thảo Điền | 188/A6 Nguyễn Văn Hưởng | [Decathlon](https://www.decathlon.vn/blog/san-pickleball-thao-dien/) |
| Sân cầu lông Tân Việt | 234 Bình Long | [ShopVNB](https://shopvnb.com/san-cau-long-tan-viet.html) |
| Sân bóng đá Thăng Long | 2 Phan Thúc Duyện | [Dương Minh FC](https://www.duongminhfc.com/chieu-sinh/249-khai-giang-lop-bong-da-co-so-thang-long-tan-binh.html) |
| Sân tennis Kỳ Hòa 2 | 138A Sư Vạn Hạnh | [Địa Điểm 247](https://diadiem247.com/tp-ho-chi-minh/san-tennis-ky-hoa-2-l424184.html) |
| Sân cầu lông Lan Minh | 60 Nguyễn Háo Vĩnh | [XBSPORTS](https://xbsports.vn/blogs/news/top-5-san-cau-long-tai-quan-tan-phu) |

Tên K99 từ hướng dẫn giao diện cũ đổi thành Lan Minh nếu vẫn khớp tên mẫu.
Sân chính Đại học Công Thương giữ nguyên danh tính hiện có.

**Chỉ tên và địa chỉ tham khảo địa điểm thật.** Ảnh, chủ sở hữu, nhân viên,
khách hàng, giá, lịch, hồ sơ, trạng thái duyệt và đánh giá đều là dữ liệu mô phỏng.
Không dùng số tài khoản, thông tin cá nhân hay chứng từ thật của cơ sở.

## Kiểm Thử Liên Vai Trò

1. Khách hàng: xem lịch, gửi minh chứng, yêu cầu hủy và theo dõi hoàn tiền.
2. Chủ sân: duyệt minh chứng/hủy, ghi nhận hoàn tiền; xem lịch, doanh thu, nhân viên và giải đấu.
3. Admin: duyệt hồ sơ sân/chủ sân/loại sân/hoạt động/hội nhóm; kiểm duyệt và xem báo cáo.
4. Nhân viên: đăng nhập trực tiếp, xem ca, thu lịch chưa có hồ sơ thanh toán, điểm danh đúng giờ.
5. Nhân viên chỉ xem: không được điểm danh hoặc thu tiền.
6. Đóng/mở lại ứng dụng: dữ liệu và quyết định vừa thực hiện không bị đặt lại.

Bộ mẫu không tạo ra tính năng chưa có: backend, thanh toán thật, gửi email thật,
hoặc nhiều admin phân quyền cho nhau.
