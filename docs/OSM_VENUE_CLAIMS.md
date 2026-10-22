# Yêu cầu quyền quản lý sân OSM

## Phạm vi bước 1

Luồng hoạt động trong ứng dụng demo, dữ liệu được lưu bằng SessionStore hiện có
trên cùng thiết bị. Không có backend đồng bộ, không xác thực quyền sở hữu cơ sở
ngoài thực tế. Không sử dụng giấy tờ cá nhân thật khi kiểm thử.

- Chủ sân: Sân của tôi -> Nhận quản lý sân có sẵn -> Sân có sẵn -> chọn địa điểm.
- Hoặc mở chi tiết địa điểm OSM -> Yêu cầu quản lý sân.
- Điền người đại diện, số điện thoại, căn cứ quản lý và ảnh JPG/PNG <= 400 KB.
- Gửi yêu cầu, theo dõi trạng thái; chỉ yêu cầu đang chờ được rút lại.
- Admin: Duyệt -> Quyền quản lý sân -> chọn hồ sơ -> đối chiếu ảnh và vị trí.
- Duyệt hoặc từ chối bằng mật khẩu Admin. Từ chối phải có lý do 5-300 ký tự.
- Hồ sơ bị từ chối hoặc đã rút có thể gửi lại khi sân chưa có hồ sơ đang hoạt động.

## Bảo vệ dữ liệu

Chỉ chủ sân gửi yêu cầu; khách và nhân viên không được truy cập ảnh minh chứng.
Admin xem toàn bộ hồ sơ, chủ sân chỉ xem hồ sơ của tài khoản mình. Mỗi địa điểm
chỉ có một yêu cầu pending/approved; kiểm tra phiên bản chống gửi/duyệt lặp hoặc
xử lý hồ sơ cũ. Xác nhận Admin dùng cơ chế khóa sau nhiều lần sai mật khẩu hiện có.
Lưu người xét duyệt, thời gian và nhật ký thao tác. Tối đa 100 hồ sơ trong bản demo.
Khôi phục snapshot cũ không có venueClaims vẫn tương thích. Snapshot sai tham chiếu
tài khoản, trùng quyền quản lý hoặc ảnh không hợp lệ sẽ bị từ chối toàn bộ.

## Sau khi duyệt

Quyền được ghi nhận bằng hồ sơ approved, không thay đổi dữ liệu OSM gốc,
không tạo bản sao sân và không thay đổi bookingEnabled. Hồ sơ đã duyệt xuất hiện
trong danh sách yêu cầu của chủ sân và lịch sử xét duyệt Admin.
Bước 2 đã nối hồ sơ approved với biểu mẫu thông tin sân, số sân con, giờ mở cửa,
giá cơ bản và tài khoản nhận tiền mô phỏng. Chủ sân bấm “Cấu hình sân để nhận lịch”,
gửi hồ sơ vận hành, admin duyệt hồ sơ cơ sở thì sân mới nhận đặt lịch.
Xem hướng dẫn đầy đủ tại [CLAIMED_VENUE_ACTIVATION.md](CLAIMED_VENUE_ACTIVATION.md).
Trước triển khai thực tế cần backend, kiểm tra giấy tờ, bảo vệ tệp, phân quyền
phía máy chủ và ràng buộc duy nhất trong cơ sở dữ liệu.
