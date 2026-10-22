# Rà soát tài liệu và sơ đồ

Ngày kiểm tra: 10/10/2026. Nguồn đối chiếu: `D:/PTUDDD/test_do_an`, không phải mô hình đặt sân dựng độc lập với bài đang làm.

## Những điểm đã sửa

- Đi lại đường nối use case, class, ERD, deployment và trạng thái, tránh đi xuyên ô hoặc chữ. Chừa khoảng giữa các bảng ERD rộng hơn.
- Dùng cùng tọa độ đường nối và điểm neo cho SVG/PDF và file draw.io. Đầu nối ô ellipse và hình tác nhân được chỉnh theo hình, không chỉ theo khung chữ nhật bao quanh.
- Các đường giao nhau cần thiết có cầu vượt. Đường quan hệ không có mũi tên không biểu diễn thứ tự thao tác.
- Đường sống sequence dừng trước vùng ghi chú; lời gọi nội bộ chính nó có mũi tên quay lại, không phải đoạn thẳng giả.
- Sitemap tách các mục cùng vai trò thành nhánh độc lập, không nối liên tiếp như quy trình bắt buộc.
- Sửa nhãn quản lý người dùng của admin từ UC01 sang nhóm UC16, bổ sung đặc tả tương ứng và FR29.
- Sửa tham số reviewFacility theo code: approve, reject, note, expectedRevision. Phân biệt thuộc tính của DemoActivity và DemoEvent; dùng scheduledStart, durationMinutes thay cho tên schedule không có trong lớp.
- Chỉnh xuống dòng tên hàm dài, rà chữ và dấu tiếng Việt, kiểm tra UTF-8/NFC, ký tự lỗi và tên file nguồn.
- Sửa bộ sinh ID để không trùng hình khi bố trí lại nhãn ERD; kiểm tra lại toàn bộ ID và đầu nối trong XML.

## Kết quả kiểm tra

- 24 trang sơ đồ có đường nối tường minh. Kiểm tra hình học không phát hiện đoạn đường nối đi qua ô/chữ khác hoặc hai quan hệ trùng đoạn. Vùng tiêu đề của khung hệ thống cũng được kiểm tra.
- 41 tên lớp, hàm, enum hoặc tham số được đối chiếu trực tiếp với mã Flutter; 27 file văn bản/sơ đồ đạt kiểm tra mã hóa và chuẩn hóa dấu.
- 37 kiểm tra SQL, XML, đường dẫn draw.io và kích thước hình được chạy lại. Chi tiết nằm trong các file JSON kiểm tra.
- Ảnh kết xuất sơ đồ và PDF được dùng để rà bố cục. Đây là kiểm tra tài liệu, không phải chạy lại toàn bộ test Flutter.

## Cách hiểu và giới hạn

Điểm giao của thông điệp và đường sống trong sequence là ký pháp đúng, không phải lỗi chồng đường. Bốn vai trò nghiệp vụ không đồng nghĩa bốn giá trị DemoRole: code hiện có ba giá trị enum và phiên nhân viên riêng. Lưu trữ đang dùng secure JSON snapshot; ERD/SQL và deployment backend được ghi rõ là đề xuất.

Kiểm tra tự động hỗ trợ phát hiện lỗi hình học/mã hóa, không chứng minh tuyệt đối mọi cách hiểu UML, mọi câu chữ hoặc mọi quy tắc nghiệp vụ. Khi chỉnh sửa sơ đồ thủ công cần kiểm tra lại bố cục; khi source thay đổi cần cập nhật tài liệu và chạy lại các script. Link draw.io cũ không tự cập nhật, hãy dùng các link trong danh mục bàn giao mới.
