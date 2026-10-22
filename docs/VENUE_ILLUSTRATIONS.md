# Ảnh minh họa sân thể thao

Tạo ngày 19/10/2026 bằng công cụ image_gen tích hợp. Bộ 8 ảnh nằm trong
`assets/illustrations/venues/`: cầu lông, pickleball, bóng đá, bóng đá trong nhà,
bóng rổ, quần vợt, bóng bàn và sân đa năng.

Đây là ảnh AI tượng trưng theo môn thể thao, không phải ảnh thật và không xác
nhận cơ sở vật chất của bất kỳ sân có tên cụ thể nào. Các sân cùng môn dùng
chung ảnh. Môn chưa nhận diện dùng ảnh khu thể thao đa năng.

`lib/widgets/venue_image.dart` ưu tiên ảnh hiện có, chỉ chọn ảnh minh họa khi
thiếu ảnh hoặc ảnh tải lỗi. Ảnh lớn có nhãn “Ảnh minh họa”; ảnh thu nhỏ có
biểu tượng thông tin, tooltip và mô tả hỗ trợ đọc màn hình.

`lib/venues/venue_illustrations.dart` ánh xạ môn chính sang tài nguyên ảnh.
Không thay đổi dữ liệu OSM gốc, giá, trạng thái xác minh hay quyền đặt sân.
Sau khi chủ sân thêm ảnh, giao diện tự ưu tiên ảnh mới.

Prompt đầy đủ và nguồn tạo của từng ảnh được ghi trong
`docs/venue_illustration_prompts.json`.
