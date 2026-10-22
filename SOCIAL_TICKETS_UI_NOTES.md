# Vé Social Tại Sân

## Đường Dẫn Kiểm Thử

- Khách hàng → Đặt sân → Mua vé social; hoặc lối tắt Social ở Trang chủ.
- Chọn ngày → Chi tiết sự kiện → Mua vé → Chọn 1–2 vé → Thông tin người mua → Đồng ý điều khoản → Tiếp tục thanh toán.
- Tải ảnh thử nghiệm JPG/PNG, tối đa 400.000 byte → Hoàn thành → Vé social đã mua → Xem chi tiết.
- Tài khoản → Vé social đã mua có bộ lọc Tất cả, Đã tham gia, Hết hạn và Đã hủy.
- Chủ sân/nhân viên được phân quyền dùng luồng quản lý vé hiện có để duyệt chứng từ, điểm danh và xử lý yêu cầu hủy. Mã QR chỉ xuất hiện sau khi thanh toán được xác nhận.

## Quy Tắc Đã Chốt

- Đơn social mới tạo giữ chỗ tối đa 15 phút, không vượt thời điểm kết thúc sự kiện. Thời hạn được lưu cùng đơn, không bắt đầu lại khi mở màn thanh toán.
- Đến đúng hạn mà chưa gửi chứng từ: tự hủy vé, trả đủ số chỗ, ghi nhật ký hệ thống. Tải ảnh nhưng chưa bấm Hoàn thành vẫn là chưa gửi.
- Không khôi phục đơn đã tự hủy. Nút Chọn mua vé mới mở danh sách để mua một đơn khác nếu còn chỗ.
- Đã gửi chứng từ: giữ vé để chờ chủ sân xác nhận; không báo đã thanh toán và không tự hủy theo đồng hồ chờ chứng từ.
- Chứng từ bị từ chối: vé vẫn giữ chỗ; mở lại thanh toán để bổ sung trong một thời hạn mới. Chứng từ cũ được giữ cho đến lần gửi mới.
- Có thể mua vé khi sự kiện đang diễn ra nếu chưa kết thúc và còn chỗ. Không thay đổi điều kiện đăng ký của luồng giải đấu cũ.
- Mua 2 vé trong cùng đơn social mới được giảm 10%; số tiền dùng VND nguyên. Vé của luồng cũ không bị áp lại ưu đãi.
- Yêu cầu hủy chỉ hợp lệ khi còn ít nhất 24 giờ và chưa check-in. Gửi yêu cầu không lập tức hủy vé, trả chỗ hay hoàn tiền.
- Thời lượng và ngày giờ hiển thị được tính từ sự kiện, không chép các giá trị ngày giờ không nhất quán trong ảnh mẫu.

## Dữ Liệu Và Giới Hạn

- Sử dụng DemoEvent, DemoParticipation, DemoPayment và kho lưu cục bộ hiện có; không tạo một danh sách vé rời khỏi hệ thống quản lý.
- DemoParticipation bổ sung socialCheckout và note, đọc tương thích snapshot cũ. Đơn social mới bắt buộc có bản ghi thanh toán khi khôi phục.
- Dữ liệu sự kiện hiện chỉ gắn sân chính Đại Học Công Thương. Sân khác hiển thị chưa có sự kiện; không gán nhầm vé giữa các sân.
- Ảnh dùng tài nguyên có sẵn trong assets/figma; không thêm ảnh từ nguồn bên ngoài.
- Chuyển khoản là mô phỏng, không có tài khoản ngân hàng thật hoặc yêu cầu chuyển tiền thật.
- Đây là ứng dụng demo lưu cục bộ. Khi ứng dụng đóng, không có máy chủ chạy đồng hồ; khi mở lại, hệ thống đối chiếu deadline đã lưu và xử lý vé quá hạn. Không phải đồng bộ số chỗ giữa nhiều thiết bị.
- Tự hủy social không thay đổi chính sách hết hạn của đặt sân theo giờ hay các vé cũ.

## Kiểm Thử

- test/social_checkout_test.dart: thời hạn, trả chỗ, giữ vé đã gửi chứng từ, khôi phục dữ liệu, ưu đãi, giới hạn vé, phân quyền, mua khi đang diễn ra và yêu cầu hủy.
- test/social_checkout_widget_test.dart: lựa chọn hình thức đặt, chọn số lượng, điều khoản, tải chứng từ, lịch sử, hộp thoại hết hạn và bố cục 320/402 px với cỡ chữ 1×/2×.
- Các kiểm thử đặt sân từ trang chi tiết đã thêm bước chọn Đặt lịch theo sân để phản ánh giao diện mới.

Tài liệu báo cáo lần 1 được tạo trước phần social này; khi dùng báo cáo cho phiên bản mới, cần bổ sung các quy tắc và trường dữ liệu ở trên vào URD, sequence, ERD và class diagram.

## Kết Quả Ngày 10/10/2026

- 199/199 ca đạt trong 15 tệp kiểm thử đã chọn, gồm 20 ca social mới và hồi quy các luồng liên quan.
- Phân tích tĩnh 12 tệp mã/kiểm thử thay đổi: No issues found.
- flutter build bundle --debug: thành công; mã Dart và tài nguyên Flutter biên dịch được.
- flutter build apk --debug: chưa thành công do Java/Gradle báo Unable to establish loopback connection, kể cả lần thử IPv4. Chưa tạo hoặc cài APK mới.
- adb devices không thấy thiết bị Android kết nối tại thời điểm kiểm tra.
- Đã xuất và rà ảnh giao diện social ở build/previews/social_*.png; các ca bố cục kiểm tra cả đầu và cuối trang trên màn hình 320/402 px, cỡ chữ 1×/2×.
