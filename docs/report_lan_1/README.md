# Bộ tài liệu báo cáo đồ án lần 1

Ngày đối chiếu source: 10/10/2026. Bộ này không chỉnh sửa code ứng dụng hoặc reset dữ liệu demo.

## Mở tài liệu

1. Mở `index.html` để xem danh mục. Không cần server.
2. Đọc `BAO_CAO.pdf` hoặc `BAO_CAO.html`; sửa nội dung nguồn tại `BAO_CAO.md`.
3. Mở `drawio_links.html`, chọn **Mở draw.io** ở sơ đồ cần xem/chỉnh sửa.
4. Hoặc vào https://app.diagrams.net/ , chọn Device rồi Open Existing Diagram và mở `SportMatch_Lan1.drawio`.
5. File draw.io đầy đủ có 24 trang; shape, chữ và connector đều chỉnh sửa được. Các SVG trong diagrams chỉ để xem/in.

Link draw.io chứa dữ liệu sơ đồ trong URL, mở một bản sao, không phải link Drive cộng tác đồng bộ. Link không gửi source, tài khoản hay chứng từ ứng dụng lên dịch vụ lưu trữ. Cần Internet để tải trình biên tập draw.io; có thể mở file bằng draw.io Desktop nếu đã cài. Nếu hệ thống chặn URL dài, dùng file `.drawio` nhiều trang.

## Nội dung

- URD: tác nhân, phạm vi, 30 yêu cầu chức năng, 10 yêu cầu phi chức năng và 12 quy tắc nghiệp vụ.
- 16 đặc tả use case; 5 trang use case diagram (tổng quan và 4 vai trò).
- 6 sequence diagram, có luồng thành công và nhánh ngoại lệ.
- 6 ERD theo miền nghiệp vụ, 2 class diagram hiện trạng.
- 2 deployment diagram: hiện trạng cục bộ và backend dự kiến.
- 1 sitemap UI/UX, 2 state diagram, ảnh minh chứng từ test/emulator.
- SQL SQLite thiết kế 45 bảng, từ điển dữ liệu tự sinh và test ràng buộc.
- Bảng truy vết, 20 kịch bản nghiệm thu thủ công và giới hạn triển khai.

## Chạy SQL tham khảo

SQL chỉ là thiết kế đề xuất; Flutter hiện tại vẫn dùng secure JSON snapshot. Không chạy file này lên DB đang có dữ liệu vì đây là DDL tạo mới, không phải migration. Không có mật khẩu hoặc chứng từ thật trong SQL.

Với SQLite CLI đã cài, mở một database mới rồi nhập:

```sql
.read schema.sql
PRAGMA foreign_keys = ON;
PRAGMA foreign_key_check;
```

`.read` là lệnh của SQLite CLI, không phải SQL chuẩn. Phải bật foreign_keys cho mỗi kết nối ứng dụng. Có thể kiểm tra không cần SQLite CLI bằng `validate_documents.py`, sử dụng sqlite3 trong Python và DB in-memory.

```powershell
python build_documents.py
python validate_documents.py
python audit_diagrams.py
python audit_sources.py
```

Bộ sinh sử dụng Python + Pillow để tính kích thước chữ; trên máy hiện tại chạy bằng Python runtime của Codex. `render_report.cjs` dùng Playwright và Edge để xuất PDF/ảnh kiểm tra, các đường dẫn runtime được ghi trong script. Không cần các công cụ này chỉ để đọc hoặc sửa draw.io/Markdown.

## Trước khi nộp

- Điền trường, học phần, giảng viên, lớp, nhóm và mã sinh viên.
- Thống nhất tên SportMatch hoặc NVH Sports; không đổi tên UI bằng việc sửa tài liệu.
- Chốt thẻ sinh viên có bắt buộc cho mọi khách hay chỉ một nhóm; nguyên mẫu đang yêu cầu theo checkout hiện tại.
- Xác nhận chính sách hủy sân và vé hoạt động riêng biệt, không dùng một ngưỡng cho mọi tình huống.
- Kiểm thử điện thoại thật và các plugin; chưa đánh dấu đã đạt trong báo cáo.
- Không nói đã có backend, DB quan hệ, thanh toán thật, email thật hay đồng bộ nhiều máy.
- Dùng file `.drawio` làm bản gốc lưu trữ. Chỉnh sửa trên URL rồi lưu bản mới, link cũ không cập nhật.

## Nguồn và kiểm tra

Nguồn nội bộ được liệt kê cuối báo cáo. Nguồn draw.io/SQLite là tài liệu chính thức, chỉ hỗ trợ định dạng và công cụ. Kết quả kiểm tra bộ tài liệu nằm ở `validation_results.json`; không thay thế kết quả test Flutter.

`manifest.json` ghi số trang sơ đồ và số bảng. `schema.sql` có chú thích những điều phải xử lý ở tầng ứng dụng/giao dịch. Một ERD chỉ vẽ quan hệ trong trang; mọi khóa ngoại và cột có trong `data_dictionary.html`.

## Rà soát bổ sung

Xem `KIEM_TRA.md` để biết các lỗi đã sửa và phạm vi kiểm tra. `diagram_review.json` ghi kiểm tra đường nối trên 24 trang; `source_review.json` ghi đối chiếu 41 tên lớp/hàm/tham số với source đang làm. Các script không sửa source ứng dụng. `audit_sources.py` cần đường dẫn dự án hiện tại; đổi biến PROJECT nếu chuyển máy.
