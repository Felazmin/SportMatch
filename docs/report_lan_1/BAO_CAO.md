# Phân tích thiết kế hệ thống đặt sân thể thao SportMatch

Báo cáo đồ án lần 1 về phân tích thiết kế hệ thống thông tin và nguyên mẫu giao diện. Tài liệu được lập từ source Flutter tại `D:/PTUDDD/test_do_an`, đối chiếu ngày 10/10/2026. Tên hiển thị hiện tại của ứng dụng là NVH Sports; SportMatch là tên nghiệp vụ trong một số mẫu thiết kế. Nhóm cần thống nhất tên chính thức trước khi nộp.

**Thông tin cần bổ sung trước khi nộp:** trường, khoa, học phần, giảng viên, lớp, nhóm, thành viên và mã sinh viên. Tài liệu không tự điền các thông tin chưa được cung cấp.

## 1 Tổng quan và phạm vi

### 1.1 Bài toán

Người chơi cần tìm sân, chọn giờ trống, đặt sân, gửi chứng từ thanh toán và theo dõi xác nhận. Chủ sân cần quản lý cơ sở, lịch, giá, nhân viên và các yêu cầu của khách. Nhân viên chỉ thực hiện nghiệp vụ được giao tại cơ sở được phân công. Admin kiểm duyệt cơ sở, người dùng và nội dung cộng đồng.

Mục tiêu của lần báo cáo này là chứng minh được layout, cấu trúc chương trình và các luồng UI/UX có dữ liệu kiểm thử. Báo cáo không khẳng định đã hoàn thành hệ thống thương mại hoặc backend đa người dùng.

### 1.2 Ranh giới triển khai

| Hạng mục | Hiện trạng | Cách thể hiện trong báo cáo |
| --- | --- | --- |
| Ứng dụng khách | Flutter, có APK Android debug chạy trên giả lập | Đã triển khai nguyên mẫu |
| Nghiệp vụ | Xử lý bằng DemoSession và các extension theo nhóm chức năng | Đã triển khai cục bộ |
| Dữ liệu | Snapshot JSON lưu qua FlutterSecureStorage | Đã triển khai cục bộ, không phải DB quan hệ |
| Thanh toán | Gửi ảnh chứng từ và xác nhận thủ công; giải đấu có thanh toán mô phỏng | Không kết nối ngân hàng hoặc ví thật |
| Bản đồ | Tile mạng, tra địa chỉ và GPS theo quyền thiết bị | Phụ thuộc mạng và dịch vụ ngoài |
| Thông báo và email | Trạng thái/thông báo trong ứng dụng | Chưa có dịch vụ gửi email hoặc push thật |
| Backend và DB quan hệ | Chưa nối vào ứng dụng | Thiết kế đề xuất trong SQL và ERD |
| Chạy nhiều thiết bị | Mỗi thiết bị có dữ liệu riêng | Chưa đồng bộ; demo liên vai trò trên cùng thiết bị |
| iOS và web | Có thư mục iOS; không có thư mục web trong source hiện tại | Chưa nghiệm thu trên iOS/web |

### 1.3 Những giới hạn cần công bố

Mã hiện tại có ba giá trị `DemoRole`: player, owner, admin. Nhân viên là một phiên đăng nhập riêng dựa trên `DemoEmployeeAccess`, không phải giá trị thứ tư trong enum. Về phân tích nghiệp vụ vẫn có bốn tác nhân. Một tài khoản chủ sân và một tài khoản admin mẫu không chứng minh được quản trị nhiều chủ sân/admin độc lập. Chưa có ủy quyền một phần từ admin này sang admin khác.

Tên và địa chỉ sân có tham khảo địa điểm tại TP.HCM; ảnh, giá, số sân, hồ sơ, người sở hữu và giao dịch là giả lập. Không trình bày các giá trị này như thông tin chính thức của cơ sở thật.

## 2 URD và yêu cầu người dùng

### 2.1 Tác nhân

| Mã | Tác nhân | Mục tiêu và phạm vi |
| --- | --- | --- |
| A0 | Khách chưa đăng nhập | Xem nội dung công khai, tìm sân, đăng ký/đăng nhập |
| A1 | Khách hàng | Đặt sân, thanh toán mẫu, hủy, đánh giá, tham gia hoạt động/cộng đồng và quản lý tài khoản của mình |
| A2 | Chủ sân | Quản lý hồ sơ cơ sở, lịch, giá, thanh toán, hủy/hoàn tiền, nhân viên, hoạt động và doanh thu |
| A3 | Nhân viên quản lý sân | Xem lịch, điểm danh, thu tại sân trong quyền và cơ sở được giao |
| A4 | Admin | Kiểm duyệt bảy nhóm quản lý, xem báo cáo và thiết lập nghiệp vụ hiện có |

### 2.2 Danh mục yêu cầu chức năng

| Mã | Yêu cầu | Điều kiện nghiệm thu chính |
| --- | --- | --- |
| FR01 | Đăng ký, đăng nhập, đăng xuất, cập nhật tài khoản | Dữ liệu hợp lệ; tài khoản khóa bị chặn; không lộ dữ liệu tài khoản khác |
| FR02 | Phân biệt không gian khách hàng/chủ sân/admin/nhân viên | Điều hướng đúng phiên; nghiệp vụ kiểm tra quyền, không chỉ ẩn nút |
| FR03 | Tìm và xem sân công khai | Cơ sở chưa duyệt hoặc bị ngưng không nhận đặt mới |
| FR04 | Xem bản đồ và sân yêu thích | Từ chối GPS không làm ứng dụng sập; yêu thích riêng theo tài khoản |
| FR05 | Chọn sân con, ngày, giờ và thời lượng | Chặn trùng lịch, ngoài giờ hoặc sân bị khóa |
| FR06 | Xác nhận thông tin đặt sân và giá | Hiển thị liên hệ, tổng tiền, điều khoản; lưu giá/chính sách tại thời điểm đặt |
| FR07 | Gửi chứng từ thanh toán | Checkout có hạn tối đa 15 phút; ảnh chứng từ/thẻ sinh viên theo luồng hiện tại |
| FR08 | Chủ sân xử lý chứng từ | Chỉ xử lý hồ sơ đang chờ; từ chối phải có lý do |
| FR09 | Xem lịch và chi tiết lịch đặt | Chỉ khách sở hữu hoặc người quản lý hợp lệ được xem |
| FR10 | Gửi yêu cầu hủy lịch | Kiểm tra hạn yêu cầu, trạng thái và thông tin nhận hoàn |
| FR11 | Duyệt hủy và ghi nhận hoàn tiền | Yêu cầu hủy chưa làm lịch bị hủy; ghi nhận hoàn là thao tác thủ công |
| FR12 | Đánh giá và báo cáo đánh giá | Chỉ lịch đủ điều kiện mới được đánh giá; admin ẩn/giữ có lý do |
| FR13 | Tạo và gửi hồ sơ cơ sở | Lưu nháp, đính kèm hồ sơ mẫu, gửi duyệt; không tự công khai |
| FR14 | Sửa hồ sơ đang chờ | Chủ sở hữu sửa đúng phiên bản; hồ sơ vẫn chờ admin xem lại |
| FR15 | Duyệt, yêu cầu bổ sung hoặc từ chối hồ sơ | Admin kiểm tra phiên bản; bản công khai lấy từ nội dung đã duyệt |
| FR16 | Quản lý lịch sân và khóa giờ | Xung đột với đặt sân hoặc phân bổ hoạt động bị chặn |
| FR17 | Đề xuất và duyệt bảng giá | Giá mới không sửa lại hợp đồng đặt sân cũ |
| FR18 | Tạo nhân viên và phân quyền theo cơ sở | Quyền điểm danh/thu cần kèm xem lịch; yêu cầu mật khẩu quản lý |
| FR19 | Đăng nhập nhân viên và xem ca | Nhân viên ngừng hoạt động hoặc bị thu hồi quyền không tiếp tục thao tác |
| FR20 | Điểm danh và thu tại sân | Đúng quyền, đúng cơ sở, đúng khung giờ và trạng thái |
| FR21 | Tạo và duyệt hoạt động | Có social/tournament, sức chứa, phí, lịch và trạng thái duyệt |
| FR22 | Đăng ký hoạt động/giải đấu | Kiểm tra sức chứa và điều kiện; lưu vé cùng snapshot sự kiện |
| FR23 | Thanh toán lệ phí mô phỏng | Hiển thị phương thức, tổng tiền và xác nhận đăng ký; không chuyển tiền thật |
| FR24 | Lịch đấu, điểm danh và kết quả | Hai vé hợp lệ, không trùng đội/sân/giờ; chưa có tự động chia bảng/nhánh |
| FR25 | Hội nhóm và yêu cầu vào nhóm | Nhóm cần duyệt thành viên thì chưa được đăng bài khi đang chờ |
| FR26 | Diễn đàn và chia chi phí | Nội dung gắn đúng người dùng; mô hình chia chi phí chỉ là ghi nhận cục bộ |
| FR27 | Tin nhắn và hỗ trợ | Tin/ảnh/âm thanh là dữ liệu demo, không phải chat thời gian thực giữa hai máy |
| FR28 | Báo cáo thu chi và doanh thu | Dựa ngày nhận/hoàn tiền được ghi nhận; không dùng giờ chơi làm ngày nhận tiền |
| FR29 | Quản lý bảy nhóm của admin | Sân, chủ sân, người dùng, đánh giá, loại sân, hoạt động, hội nhóm |
| FR30 | Lưu và khôi phục dữ liệu | Đóng/mở lại giữ thao tác; lỗi lưu cho phép thử lại, không báo thành công sai |

### 2.3 Ma trận quyền nghiệp vụ

| Nghiệp vụ | Khách hàng | Chủ sân | Nhân viên | Admin |
| --- | --- | --- | --- | --- |
| Đặt sân và gửi chứng từ | Lịch của mình | Không dùng vai trò quản trị để đặt thay | Không | Không dùng vai trò quản trị để đặt thay |
| Duyệt thanh toán/hủy, hoàn tiền | Không | Có trong nguyên mẫu | Không | Có theo nghiệp vụ hiện có |
| Xem lịch vận hành | Lịch của mình | Có | Quyền schedule và cơ sở được giao | Có |
| Điểm danh | Xem trạng thái | Có | Quyền attendance | Có |
| Thu tại sân | Không | Có | Quyền onsite, chỉ lịch đặt sân | Có |
| Cấp quyền nhân viên | Không | Có | Không | Có trong nguyên mẫu |
| Duyệt hồ sơ/danh mục | Không | Gửi hồ sơ | Không | Có |
| Quản trị tài khoản người dùng | Tài khoản mình | Không phải quyền admin | Không | Có |
| Xem doanh thu quản trị | Không | Có | Không | Có |

Phạm vi nhiều chủ sân phải được kiểm tra lại khi chuyển sang backend. Bảng quyền không thay thế rà soát từng API; ứng dụng hiện tại là mô hình một chủ sân demo.

### 2.4 Yêu cầu phi chức năng

| Mã | Yêu cầu | Tiêu chí lần 1 và kế hoạch |
| --- | --- | --- |
| NFR01 | Dễ sử dụng | Điều hướng nhất quán; phân biệt chờ/xác nhận/từ chối; nút gửi có phản hồi |
| NFR02 | Khả năng đọc | Kiểm tra màn hình hẹp và tăng cỡ chữ; chưa chứng nhận toàn bộ WCAG |
| NFR03 | Toàn vẹn | Chặn trùng lịch, sai quyền, sai phiên bản; restore toàn bộ snapshot hợp lệ |
| NFR04 | Bền vững dữ liệu | Khôi phục sau khởi động; có trạng thái lỗi lưu và thử lại |
| NFR05 | Bảo mật | Chỉ dùng thông tin thử; secure storage không thay thế hash mật khẩu và phân quyền server |
| NFR06 | Hiệu năng | Mục tiêu thử nghiệm thao tác thường phản hồi trong 2 giây, không tính chọn file/mạng; chưa đo chuẩn |
| NFR07 | Khả năng bảo trì | Chia màn hình, mô hình, nghiệp vụ; bổ sung service/repository khi có backend |
| NFR08 | Khả năng triển khai | APK Android cài được; điện thoại thật, release và iOS/web là phần cần nghiệm thu thêm |
| NFR09 | Riêng tư | Giấy tờ pháp lý không công khai; không dùng CCCD, chứng từ hay tài khoản ngân hàng thật |
| NFR10 | Đồng thời | Bản cục bộ kiểm tra revision; backend dự kiến cần giao dịch DB và chống gửi lặp |

### 2.5 Quy tắc nghiệp vụ

BR01. Một sân con không nhận hai lịch đang chiếm chỗ giao nhau. Khóa sân và phân bổ sự kiện cũng chiếm chỗ. Khoảng thời gian dùng dạng nửa mở [bắt đầu, kết thúc), nên hai lịch sát nhau được phép.

BR02. Giá từng giờ và chính sách hủy được chụp tại thời điểm đặt. Thay đổi giá hoặc chính sách sau đó không tự sửa hợp đồng cũ. Tiền VND dùng số nguyên, không dùng số thực để tính phí.

BR03. Checkout khách hàng dùng hạn tối đa 15 phút, không vượt giờ bắt đầu; một số luồng chuyển khoản khác dùng 30 phút. `DemoPayment.expired` chỉ áp dụng khi còn chờ chứng từ/bị từ chối. Hết hạn không tương đương ngân hàng hoàn tiền.

BR04. Gửi ảnh làm thanh toán chuyển sang pending, chưa phải approved. Chủ sân/admin duyệt thủ công. Luồng giải đấu có `simulatedGateway`, phải được ghi rõ là mô phỏng.

BR05. Checkout đặt sân yêu cầu ảnh thanh toán và thẻ học sinh/sinh viên như UI hiện có. Đây là điều kiện của nguyên mẫu hiện tại, không nên khẳng định mọi khách thực tế đều bắt buộc có thẻ; cần xác nhận lại yêu cầu ở lần sau.

BR06. Với checkout, hạn yêu cầu hủy ít nhất 2 giờ hoặc lớn hơn nếu chính sách lưu trong lịch yêu cầu. Tại đúng hạn còn được gửi (`now` không lớn hơn hạn). Chính sách chuẩn hoàn 95% sớm, 50% muộn; checkout có thể không cho gửi ở nhánh muộn. Không áp dụng một mức 95% cho mọi loại lịch.

BR07. Gửi yêu cầu hủy chỉ tạo requested. Chỉ sau chấp thuận mới hủy lịch; hoàn tiền pending khác recorded. Chưa duyệt thanh toán thì ước tính hoàn bằng 0. Vé hoạt động có quy tắc hủy/hoàn riêng, không dùng chính sách sân.

BR08. Nhân viên phải đang hoạt động, có quyền và đúng cơ sở. Quyền attendance/onsite cần schedule. Luồng thu tại sân chỉ hỗ trợ lịch đặt sân, không thu vé giải đấu bằng quyền này.

BR09. Duyệt và sửa hồ sơ kiểm tra phiên bản hiện tại. Cơ sở có bản draft và published; chỉ bản đã duyệt mới công khai. Yêu cầu bổ sung được biểu diễn bằng state rejected kết hợp reviewDecision supplement.

BR10. Điểm danh kiểm tra mốc thời gian của code, gồm mốc 30 phút trước giờ chơi. Không tự cho phép điểm danh mọi lịch tương lai để tiện demo.

BR11. Đăng ký hoạt động kiểm tra ngày, sức chứa, số vé và liên kết hội nhóm nếu có. Đăng ký lưu snapshot của sự kiện để phí/lịch đã nhận không đổi theo danh mục mới.

BR12. Nhật ký hiện tại lưu cục bộ và có giới hạn; không coi là audit ledger bất biến. Báo cáo doanh thu dựa ngày ghi nhận thu/hoàn, không suy diễn từ ngày đặt sân.

## 3 Use case và đặc tả

### 3.1 Danh mục use case

| Mã | Use case | Tác nhân chính | Yêu cầu |
| --- | --- | --- | --- |
| UC01 | Đăng nhập và chọn không gian | A1 A2 A3 A4 | FR01 FR02 |
| UC02 | Tìm sân và đặt lịch | A1 | FR03 FR04 FR05 FR06 |
| UC03 | Gửi chứng từ và xác nhận thanh toán | A1 A2 A4 | FR07 FR08 |
| UC04 | Xem lịch và yêu cầu hủy | A1 | FR09 FR10 |
| UC05 | Duyệt hủy và ghi nhận hoàn | A2 A4 | FR11 |
| UC06 | Thêm sửa và gửi hồ sơ sân | A2 | FR13 FR14 |
| UC07 | Kiểm duyệt cơ sở | A4 | FR15 |
| UC08 | Quản lý lịch khóa giờ và bảng giá | A2 A4 | FR16 FR17 |
| UC09 | Phân quyền nhân viên | A2 A4 | FR18 |
| UC10 | Nhân viên vận hành lịch sân | A3 | FR19 FR20 |
| UC11 | Tạo và duyệt hoạt động | A2 A4 | FR21 |
| UC12 | Đăng ký và thanh toán giải đấu | A1 | FR22 FR23 |
| UC13 | Lịch đấu điểm danh kết quả | A2 A4 A1 | FR24 |
| UC14 | Hội nhóm diễn đàn và chia chi phí | A1 A4 | FR25 FR26 |
| UC15 | Đánh giá và kiểm duyệt | A1 A4 | FR12 FR29 |
| UC16 | Báo cáo, hỗ trợ và tài khoản | A1 A2 A4 | FR27 FR28 FR29 FR30 |

Sơ đồ draw.io gồm tổng quan và bốn trang chi tiết. Đường nối tác nhân là association, không phải thứ tự thực hiện. Quan hệ include/extend chỉ dùng khi thật sự bắt buộc/tùy điều kiện; không ghép toàn bộ quy trình thanh toán thành một use case đăng nhập.

### 3.2 UC01 Đăng nhập và chọn không gian

**Tiền điều kiện:** ứng dụng nạp dữ liệu xong. **Kích hoạt:** người dùng mở đăng nhập thông thường hoặc không gian nhân viên.

1. Nhập định danh và mật khẩu, chọn đúng loại đăng nhập.
2. Session chuẩn hóa định danh, kiểm tra tài khoản/khóa hoặc nhân viên/quyền.
3. Khi hợp lệ, mở không gian tương ứng và lọc dữ liệu theo phiên.
4. Khi đăng xuất, bỏ phiên đang hoạt động, không xóa lịch sử nghiệp vụ.

**Ngoại lệ:** sai mật khẩu, bị khóa, nhân viên ngừng hoặc không có quyền; thông báo thất bại và không cấp phiên. Nhân viên sai liên tiếp có cơ chế chờ theo code. **Hậu điều kiện:** chỉ một loại phiên thao tác hiện hành; chưa có token xác thực server.

### 3.3 UC02 Tìm sân và đặt lịch

**Tiền điều kiện:** khách đăng nhập; cơ sở công khai và nhận đặt; khung giờ hợp lệ. **Kích hoạt:** bấm Đặt sân.

1. Chọn cơ sở, sân con, ngày, giờ và thời lượng.
2. Session kiểm tra phạm vi mở cửa, các lịch và khóa sân giao nhau.
3. Hiển thị thông tin lịch, liên hệ, giá từng giờ, giảm giá và điều khoản.
4. Khách xác nhận thông tin và điều khoản.
5. Tạo DemoBooking với mã riêng, giá và chính sách snapshot; mở checkout.

**Ngoại lệ:** giờ vừa bị chiếm, ngoài giờ, cơ sở ngưng, thông tin thiếu; không tạo lịch trùng. Lỗi lưu giữ trạng thái lỗi để thử lại. **Hậu điều kiện:** có lịch liên kết đúng người và cơ sở; chưa mặc nhiên đã thanh toán. **Mã nguồn:** `DemoSession.reserve`, `demo_booking.dart`, `customer_checkout_screen.dart`.

### 3.4 UC03 Gửi chứng từ và xác nhận thanh toán

**Tiền điều kiện:** lịch chưa hủy, còn hợp lệ; người gửi sở hữu lịch. **Kích hoạt:** tiếp tục thanh toán.

1. Tạo/lấy hồ sơ thanh toán và deadline từ startTransfer.
2. Hiển thị số tiền, nội dung chuyển khoản và bộ đếm; khách thực hiện chuyển tiền ngoài ứng dụng nếu thử quy trình, nhưng không dùng tiền thật trong demo.
3. Chọn ảnh chứng từ và thẻ sinh viên theo checkout; submitProof kiểm tra dữ liệu và thời hạn.
4. Chuyển thanh toán sang pending; lịch hiển thị chờ xác nhận.
5. Chủ sân/admin mở yêu cầu, duyệt hoặc từ chối kèm lý do.
6. Nếu duyệt, lưu approved và receivedAt; nếu từ chối, cho khách sửa/gửi lại khi còn hạn.

**Ngoại lệ:** thiếu ảnh, ảnh không hợp lệ, hết hạn, gửi lặp hoặc trạng thái đã xử lý. Popup hết hạn không đồng nghĩa tự hoàn tiền. **Hậu điều kiện:** trạng thái rõ ràng, không biến gửi ảnh thành xác nhận ngân hàng. **Mã nguồn:** `DemoManagement.startTransfer`, `saveProofDraft`, `saveStudentDraft`, `submitProof`, `reviewPayment`.

### 3.5 UC04 Xem lịch và yêu cầu hủy

**Tiền điều kiện:** khách sở hữu lịch có hồ sơ thanh toán. **Kích hoạt:** bấm Yêu cầu hủy lịch trong chi tiết.

1. Tính hạn từ giờ bắt đầu và chính sách snapshot, có ngưỡng checkout tối thiểu 2 giờ.
2. Nếu còn hạn, hiển thị lý do, phí và tiền dự kiến hoàn.
3. Khách nhập lý do, chọn QR hoặc thông tin ngân hàng nhận hoàn và xác nhận.
4. Session kiểm tra lại điều kiện tại thời điểm gửi, tạo requested.
5. Mở trang theo dõi chờ chủ sân phản hồi; lịch chưa bị hủy.

**Ngoại lệ:** quá hạn, lịch đã bắt đầu, đã điểm danh, đã hủy hoặc có yêu cầu đang chờ. Nhánh quá hạn hiển thị lý do và hỗ trợ, không phát sinh phí/hoàn mới. **Hậu điều kiện:** yêu cầu liên kết đúng lịch; thông tin hoàn chỉ phục vụ demo. **Mã nguồn:** `canRequestBookingCancellation`, `requestCancellation`, `customer_cancellation_screen.dart`.

### 3.6 UC05 Duyệt hủy và ghi nhận hoàn

**Tiền điều kiện:** quản lý hợp lệ; yêu cầu requested. **Kích hoạt:** mở xử lý yêu cầu hủy.

1. Xem lịch, lý do, chứng từ và chính sách đã chốt.
2. Chấp thuận hoặc từ chối; từ chối có lý do.
3. Nếu chấp thuận, cập nhật cancellation accepted, hủy lịch và xác định tiền hoàn theo thời điểm yêu cầu.
4. Nếu có tiền phải hoàn, đặt refund pending; người quản lý thực hiện hoàn ngoài hệ thống.
5. Nhập mã tham chiếu và minh chứng hoàn mẫu để recordWorkflowRefund ghi recorded; code cũng có recordDemoRefund là nhánh ghi nhận hoàn demo giản lược.

**Ngoại lệ:** hồ sơ đã xử lý, trạng thái không hợp lệ, thiếu minh chứng. **Hậu điều kiện:** tiền hoàn chỉ ghi nhận khi có thao tác xác nhận, không gọi cổng ngân hàng. **Mã nguồn:** `demo_management.dart`, `demo_workflow_session.dart`.

### 3.7 UC06 Thêm sửa và gửi hồ sơ sân

**Tiền điều kiện:** chủ sân đăng nhập, có quyền sở hữu hồ sơ. **Kích hoạt:** thêm sân hoặc chỉnh sửa trong danh sách.

1. Điền thông tin cơ sở, số sân, giờ mở/đóng, giá, ảnh, tiện ích, người đại diện, chính sách và giấy tờ mẫu.
2. Có thể lưu thông tin nhập dở riêng với hồ sơ đầy đủ.
3. Lưu hồ sơ hợp lệ bằng saveFacility; gửi duyệt bằng submitFacility.
4. Khi đang pending, sửa qua updatePendingFacility với expectedRevision; không tự chuyển sang approved.
5. Theo dõi tiến trình và phản hồi của admin.

**Ngoại lệ:** thiếu ảnh/giấy tờ, loại sân chưa được duyệt, sai phiên bản, vượt giới hạn demo hoặc sửa hồ sơ không sở hữu. **Hậu điều kiện:** có draft/pending; bản published không bị thay bằng nội dung chưa duyệt.

### 3.8 UC07 Kiểm duyệt cơ sở

**Tiền điều kiện:** admin, hồ sơ pending và đúng revision. **Kích hoạt:** chọn hồ sơ trong quản lý sân.

1. Xem hồ sơ, giấy tờ mẫu, người gửi và lịch sử.
2. Chọn duyệt, yêu cầu bổ sung hoặc từ chối.
3. Với nhánh không duyệt, nhập lý do 5–300 ký tự.
4. reviewFacility kiểm tra lại quyền/trạng thái/phiên bản.
5. Duyệt sao chép draft sang published; bổ sung/từ chối lưu quyết định và lý do.

**Ngoại lệ:** chủ sân vừa sửa, hồ sơ đã được xử lý; tải lại trước khi quyết định. **Hậu điều kiện:** dữ liệu công khai chỉ lấy phiên bản được duyệt. Không tự sửa nội dung của người gửi.

### 3.9 UC08 Quản lý lịch khóa giờ và bảng giá

**Tiền điều kiện:** quản lý cơ sở hợp lệ. **Kích hoạt:** mở lịch sân/bảng giá.

1. Chọn cơ sở và ngày, xem đặt sân/khóa/hoạt động.
2. Tạo giữ sân hoặc đổi lịch theo điều kiện, kiểm tra giao nhau.
3. Đề xuất khung giá ngày thường/cuối tuần, phụ thu, hạn áp dụng.
4. Admin xem và duyệt đề xuất.
5. Lịch đặt mới dùng bảng giá được duyệt; lịch cũ giữ giá hợp đồng.

**Ngoại lệ:** giờ trùng, đề xuất hết hạn, sai revision, sự kiện đã chiếm sân. **Hậu điều kiện:** trạng thái và nhật ký lưu cục bộ; chưa có tối ưu phân sân tự động.

### 3.10 UC09 Phân quyền nhân viên

**Tiền điều kiện:** chủ sân/admin, nhân viên đang hoạt động. **Kích hoạt:** mở quyền trong hồ sơ nhân viên.

1. Chọn schedule, attendance, onsite và toàn bộ/các cơ sở đã duyệt.
2. Nhập mật khẩu nhân viên nếu tạo/đổi và mật khẩu quản lý xác nhận.
3. configureEmployeeAccess kiểm tra quyền phụ thuộc, phạm vi, revision và mật khẩu quản lý.
4. Lưu phiên bản quyền mới, ghi nhật ký.

**Ngoại lệ:** quyền thao tác không có schedule, cơ sở chưa duyệt, mật khẩu ngắn, quyền vừa thay đổi. **Hậu điều kiện:** nhân viên đăng nhập trực tiếp; không được tự cấp quyền, duyệt hoàn hoặc quản trị người dùng.

### 3.11 UC10 Nhân viên vận hành lịch sân

**Tiền điều kiện:** phiên nhân viên hoạt động và có schedule. **Kích hoạt:** mở lịch/ca.

1. employeeSchedule chỉ trả hồ sơ trong cơ sở được phân và khoảng lịch hiện có.
2. Nhân viên xem lịch và ca của mình.
3. Nếu có attendance, chọn hồ sơ và cập nhật điểm danh sau kiểm tra thời gian/trạng thái.
4. Nếu có onsite, xác nhận thu lịch đặt sân đủ điều kiện.

**Ngoại lệ:** bị thu hồi quyền, ngoài cơ sở, trạng thái đã thay đổi, thu vé giải đấu bằng onsite. **Hậu điều kiện:** thay đổi đúng bản ghi và nhật ký; nhân viên chỉ xem không thao tác được.

### 3.12 UC11 Tạo và duyệt hoạt động

**Tiền điều kiện:** người tổ chức hợp lệ. **Kích hoạt:** tạo giao lưu/giải đấu.

1. Nhập lịch, số chỗ, lệ phí, mô tả/quy tắc, hội nhóm nếu có.
2. Lưu nháp, gửi duyệt; admin duyệt hoặc trả hồ sơ có lý do.
3. Hoạt động approved đủ điều kiện xuất hiện cho khách đăng ký.
4. Có thể phân bổ sân cho khoảng hoạt động; chặn đặt sân giao nhau.
5. Hủy hoạt động khác tạm ngưng: hủy có xử lý vé liên quan, ngưng chỉ ngăn đăng ký mới.

**Ngoại lệ:** sai sức chứa/lịch, nhóm không hợp lệ, xung đột sân, hồ sơ đã thay đổi. **Hậu điều kiện:** vé đã tạo giữ snapshot; chưa có công cụ chia bảng tự động.

### 3.13 UC12 Đăng ký và thanh toán giải đấu

**Tiền điều kiện:** khách đăng nhập; giải đang nhận đăng ký, còn chỗ. **Kích hoạt:** bấm Đăng ký tham gia.

1. Xem điều lệ, lịch, địa điểm và lệ phí.
2. Nhập thông tin người đăng ký, đồng đội/trình độ và đồng ý điều khoản.
3. joinEvent kiểm tra sức chứa/điều kiện, tạo vé theo snapshot sự kiện.
4. Chọn phương thức mô phỏng và bấm thanh toán.
5. payTournamentDemo ghi approved cùng cờ simulatedGateway; hiển thị mã đăng ký và xác nhận.

**Ngoại lệ:** hết chỗ, giải ngưng/hết hạn, thiếu thông tin hoặc vé bị thay đổi. **Hậu điều kiện:** có vé để xem lịch đấu; không có tiền được chuyển thật. Luồng chuyển khoản chứng từ cho vé là nhánh khác trong workflow.

### 3.14 UC13 Lịch đấu điểm danh kết quả

**Tiền điều kiện:** giải có vé/đội hợp lệ. **Kích hoạt:** người tổ chức mở Lịch đấu và kết quả.

1. Chọn hai vé đội khác nhau, khung 30 phút, sân và thời gian trong giải.
2. Kiểm tra trùng đội/trùng sân và ràng buộc phân bổ sân nếu đã có.
3. Khi hai đội đã điểm danh và trận kết thúc, nhập điểm tổng hợp không hòa.
4. Admin có thể sửa kết quả theo điều kiện, lý do và revision; chủ sân không ghi đè kết quả.
5. Khách có vé xem lịch/kết quả theo đội của mình.

**Ngoại lệ:** vé đã hủy, đội chưa điểm danh, trùng lịch, trận chưa hết giờ. **Hậu điều kiện:** lưu kết quả/nhật ký; chưa hỗ trợ tính thắng set, tie-break, tự lên nhánh hoặc vô địch tự động.

### 3.15 UC14 Hội nhóm diễn đàn và chia chi phí

**Tiền điều kiện:** khách đăng nhập; nhóm phù hợp trạng thái. **Kích hoạt:** vào mục Khám phá.

1. Xem nhóm/bài viết công khai, chọn tham gia.
2. Nhóm yêu cầu duyệt tạo yêu cầu chờ; chỉ thành viên hợp lệ được đăng bài.
3. Tạo bài hoặc mở hoạt động gắn nhóm; điều kiện nhóm tiếp tục được kiểm tra khi đăng ký.
4. Xem chi phí và phần chia cho người tham gia theo mô hình hiện có.
5. Admin xử lý nhóm/nội dung theo quyền; giữ nguyên lịch sử liên quan.

**Ngoại lệ:** nhóm ngưng, yêu cầu trùng, chưa được duyệt, bài bị ẩn. **Hậu điều kiện:** nội dung đúng chủ thể; chưa có chuyển tiền chia phí thực tế hoặc mạng xã hội đồng bộ.

### 3.16 UC15 Đánh giá và kiểm duyệt

**Tiền điều kiện:** khách có lịch hoàn thành đủ điều kiện, chưa đánh giá lịch đó. **Kích hoạt:** gửi đánh giá.

1. Chọn số sao và nội dung; submitVenueReview kiểm tra liên kết lịch/người dùng.
2. Hiển thị đánh giá công khai theo cơ sở nếu chưa bị ẩn.
3. Admin xem nội dung/báo cáo, chọn giữ hoặc ẩn kèm lý do theo luồng xác nhận.
4. Nội dung gốc được giữ; tổng hợp công khai không tính đánh giá đã ẩn.

**Ngoại lệ:** lịch người khác, chưa hoàn thành, trùng đánh giá, quyết định cũ. **Hậu điều kiện:** trạng thái kiểm duyệt và nhật ký được lưu, không viết lại lời khách.

### 3.17 UC16 Báo cáo, hỗ trợ và tài khoản

**Tiền điều kiện:** đúng vai trò. **Kích hoạt:** mở tài khoản/hỗ trợ hoặc báo cáo quản trị.

1. Khách quản lý liên hệ, yêu thích, phương thức thanh toán mẫu, gửi hỗ trợ và xem tin nhắn.
2. Chủ sân/admin chọn khoảng ngày/cơ sở/kênh thu để xem thu chi.
3. Tổng hợp theo ngày ghi nhận thu/hoàn; bản ghi thiếu ngày cũ được đánh dấu.
4. Xuất báo cáo theo chức năng hiện có; đóng/mở lại kiểm tra lưu trữ.
5. Admin quản lý tài khoản người dùng theo chức năng khóa/mở hiện có; khách chỉ chỉnh thông tin của mình. Đây không phải chức năng phân quyền cho admin khác.

**Ngoại lệ:** không có dữ liệu, thiếu quyền, lỗi mạng bản đồ, lỗi lưu hoặc tài liệu hỏng. **Hậu điều kiện:** không suy diễn doanh thu tương lai thành tiền đã thu.

## 4 Thiết kế kiến trúc và chương trình

### 4.1 Cấu trúc source

| Đường dẫn | Trách nhiệm |
| --- | --- |
| lib/main.dart | Khởi tạo theme, session, bộ nạp fixture và HomeScreen |
| lib/screens | Giao diện, điều hướng, biểu mẫu, dialog và xác nhận |
| lib/widgets | Design tokens và widget tái sử dụng |
| lib/auth | DemoSession, xác thực cục bộ, quyền, nghiệp vụ theo extension và lưu/khôi phục |
| lib/demo | Mô hình nghiệp vụ, enum, chính sách, danh mục và dữ liệu seed |
| lib/booking | DemoBooking và dữ liệu hợp đồng lịch đặt |
| lib/venues | Danh mục sân và dịch vụ tra địa chỉ/bản đồ |
| lib/chat | Mô hình hội thoại, ảnh và âm thanh |
| lib/reports | Xuất báo cáo admin |
| assets | Hình, icon, font đã khai báo trong pubspec |
| test | Unit/model test và widget test |
| integration_test và test_driver | Kịch bản chạy trên thiết bị và driver hỗ trợ |
| android và ios | Cấu hình nền tảng; không đồng nghĩa đã thử cả hai |
| build | Kết quả sinh ra: APK, log, ảnh; không phải source cần chỉnh tay |

### 4.2 Kiến trúc hiện tại

Flutter screen gọi DemoSession hoặc các extension nghiệp vụ. Session kiểm tra trạng thái/quyền, cập nhật mô hình và gọi notifyListeners. Snapshot JSON được xếp hàng ghi vào SessionStore; lỗi lưu hiển thị và cho phép thử lại. SecureSessionStore là triển khai lưu cục bộ; test có thể cấp store giả và đồng hồ giả.

Các file `part of` không phải các microservice độc lập. Mô hình hiện tại là prototype có state trung tâm; không gọi tên Clean Architecture, MVC hay MVVM hoàn chỉnh. Giao diện còn gọi nghiệp vụ trực tiếp, và DemoSession chứa nhiều trách nhiệm. Đây là nợ kỹ thuật cần tách khi phát triển backend.

### 4.3 Kiến trúc đề xuất

Giữ Flutter client; bổ sung lớp repository/service kết nối HTTPS API. Backend chịu trách nhiệm xác thực, phân quyền theo chủ sở hữu/cơ sở, giao dịch đặt sân, kiểm tra thời hạn, lưu DB quan hệ, quản lý tệp riêng tư và nhật ký. Client không có quyền tự quyết định đã thanh toán/đã hoàn tiền trên server.

SQL SQLite trong bộ này là thiết kế quan hệ tham khảo có thể chạy kiểm tra độc lập. Nó chưa được nối vào Flutter, chưa phải migration của snapshot hiện tại, cũng chưa phải backend production. Nếu chọn PostgreSQL/MySQL cho máy chủ, phải chuyển kiểu dữ liệu, khóa thời gian, quy tắc đồng thời và chạy lại kiểm thử trên engine đó.

### 4.4 Sequence diagram

Bộ draw.io có sáu sequence: đặt sân và xác nhận thanh toán; hết hạn checkout; yêu cầu hủy và hoàn; gửi/sửa/duyệt hồ sơ; phân quyền và thao tác nhân viên; đăng ký/thanh toán giải đấu. Lifeline UI, Session và Store là thành phần đang có, không vẽ API/DB giả như thành phần đã chạy.

Mỗi sequence dùng nhánh alt cho thành công/thất bại. Chuyển vai trò trong demo là đăng xuất/đăng nhập trên cùng thiết bị; Store không gửi thông báo đến thiết bị khác. Lưu cục bộ có thể thất bại sau thay đổi trong bộ nhớ, vì vậy sơ đồ có nhánh lỗi lưu và retry, không tuyên bố commit nguyên tử ở mức ổ đĩa cho mọi thao tác.

### 4.5 Class diagram

Hai trang mô tả lớp hiện có: lõi state/lưu trữ; miền lịch đặt/thanh toán/cơ sở/nhân viên. Các association biểu diễn khóa ID hoặc sở hữu logic; không khẳng định mọi quan hệ là con trỏ đối tượng. Extension nghiệp vụ được ghi rõ là extension trên DemoSession, không phải service được tiêm độc lập.

## 5 Thiết kế dữ liệu và ERD

### 5.1 Nguyên tắc

Phân biệt facility là cơ sở với court là sân con. Tách phiên bản hồ sơ nháp/công khai; tách đơn hàng chung, lịch đặt sân và đăng ký hoạt động; thanh toán/hủy/hoàn tham chiếu đơn hàng chung để tránh khóa ngoại đa hình không kiểm soát. Không xóa cứng lịch sử tài chính khi tài khoản hoặc cơ sở ngưng.

Ảnh/giấy tờ dự kiến lưu qua bảng documents với URI tệp riêng tư và metadata, không đưa ảnh base64 vào mọi dòng DB. Mật khẩu ở schema là password_hash, không seed mật khẩu thật. Đây là thiết kế tương lai; code demo hiện tại còn quản lý secret cục bộ dạng chuỗi trong snapshot được mã hóa bởi storage.

### 5.2 Nhóm thực thể

| Nhóm | Thực thể chính | Quan hệ cốt lõi |
| --- | --- | --- |
| Danh tính | users, roles, user_roles, employee_profiles | User nhiều vai trò trong thiết kế; nhân viên thuộc một chủ sân |
| Phạm vi nhân viên | employee_permissions, employee_facilities, employee_shifts | Nhân viên nhiều quyền/cơ sở/ca |
| Cơ sở | sports, court_types, facilities, facility_versions, courts | Một cơ sở nhiều phiên bản và sân con |
| Giá và xác minh | tariff_proposals, tariff_bands, owner_verifications | Đề xuất giá có nhiều khung; xác minh gắn chủ sân |
| Đặt sân và tài chính | orders, bookings, payments, cancellation_requests, refunds | Một đơn có một loại chi tiết; một hồ sơ thanh toán trong mô hình giản lược |
| Chiếm chỗ | court_reservations | Khoảng đặt/khóa/phân bổ sự kiện cùng bảng để chặn trùng |
| Hoạt động | events, event_occurrences, registrations, tournament_matches | Sự kiện có các lần tổ chức; vé/đội thuộc lần tổ chức |
| Cộng đồng | play_groups, group_memberships, group_join_requests, posts | Thành viên và yêu cầu vào nhóm tách biệt |
| Phản hồi | reviews, disputes, support_tickets, audit_entries | Đánh giá gắn lịch; khiếu nại gắn đơn; nhật ký gắn tác nhân |
| Bổ trợ | documents, favorites, payment_methods, courses, enrollments, expenses, expense_shares, chat_conversations, chat_participants, chat_messages, payouts, payout_items | Danh mục và quan hệ phụ trợ |

### 5.3 Ràng buộc và trách nhiệm giao dịch

SQL có PK, FK, CHECK, UNIQUE, index và trigger kiểm tra giao nhau khi INSERT/UPDATE court_reservations, chống trùng trận theo sân/đội, hạn chế vé vượt sức chứa và review không khớp chủ lịch. Bảng reservation dùng cùng không gian giờ cho đặt sân/khóa/phân bổ sự kiện.

Ứng dụng/backend tương lai vẫn phải đặt các thao tác vào giao dịch: tạo order + booking + reservation; hủy + giải phóng reservation; thu + timestamp + audit; đổi quyền + revision. DDL không tự triển khai toàn bộ máy trạng thái, thời hạn, hash mật khẩu, upload an toàn hoặc kiểm tra người gọi. File kiểm thử SQL xác nhận phạm vi ràng buộc đã viết, không thay thế test tích hợp API.

Tất cả thời gian SQL dùng Unix timestamp UTC tính bằng giây. UI chuyển sang Asia/Ho_Chi_Minh. Code hiện tại chủ yếu dùng DateTime local; cần migration rõ ràng để tránh lệch ngày. Tiền là INTEGER VND. Từ điển dữ liệu HTML được sinh trực tiếp từ SQL, gồm cột, kiểu, null/default, PK và FK.

### 5.4 Những quyết định còn mở

Chưa chốt DB máy chủ, nhà cung cấp thanh toán, quy định bắt buộc thẻ sinh viên, phạm vi dữ liệu giữa nhiều chủ sân, chính sách lưu giấy tờ, SLA, thông báo thật và chuẩn thể thức giải đấu. Schema mở rộng phạm vi nhưng các mục chưa có trong app không được đánh dấu đã hoàn thành.

## 6 Deployment diagram và triển khai

### 6.1 Triển khai đã có

Android emulator hoặc điện thoại cài APK Flutter. Trong tiến trình ứng dụng có UI, Session và mô hình; dữ liệu cục bộ lưu qua FlutterSecureStorage. Asset đóng gói trong APK. Bản đồ/tra địa chỉ gọi dịch vụ ngoài qua Internet; chọn ảnh/PDF/microphone/GPS dùng quyền và plugin thiết bị.

Hiện chưa có API server, DB server hay object storage của đồ án. File SQL tạo ra trong báo cáo là tài liệu thiết kế và công cụ kiểm thử độc lập, không thay đổi vị trí lưu dữ liệu của app.

### 6.2 Triển khai dự kiến

Flutter Android kết nối HTTPS API; API dùng DB quan hệ và kho tệp riêng tư. Dịch vụ email/push và ngân hàng/PSP là tích hợp tương lai có hợp đồng và môi trường sandbox. Khóa DB/storage nằm ở server, không trong APK. Web admin, CI/CD, load balancer và nhiều bản sao server chỉ bổ sung khi thật sự triển khai; không vẽ như hiện trạng.

### 6.3 Hướng dẫn chạy

Tại thư mục source, dùng Flutter SDK phù hợp với pubspec và cấu hình Android SDK:

```powershell
flutter pub get
flutter analyze
flutter test test/demo_seed_test.dart test/demo_seed_widget_test.dart
flutter run -d emulator-5554
flutter build apk --debug
```

APK nằm tại `build/app/outputs/flutter-apk/app-debug.apk`. Bản hiện có đã cài và mở trên emulator; không khẳng định đã thử mọi điện thoại. Trên Windows, nếu Gradle báo đường dẫn socket dài, cấu hình thư mục tạm ngắn được phép ghi trước khi build.

Release hiện dùng debug signing; package/label còn mang tên test_do_an. Trước phát hành phải đổi định danh, cấu hình release keystore riêng, quản lý version, kiểm tra backup/quyền, bật luồng backend và nghiệm thu bảo mật. Debug APK phù hợp demo lớp nhưng kích thước lớn và không phản ánh hiệu năng release.

## 7 URD giao diện và luồng UI UX

### 7.1 Điều hướng theo vai trò

Khách hàng dùng Trang chủ, Bản đồ, Khám phá, Nổi bật, Tài khoản. Các trang tài khoản gồm lịch đặt, yêu thích, phương thức thanh toán và hồ sơ. Khám phá có diễn đàn/hội nhóm/hoạt động và đăng ký giải đấu. Sơ đồ sitemap trong draw.io thể hiện các nhánh chính, không thay thế danh mục toàn bộ widget.

Chủ sân có dashboard và các mục quản lý sân: lịch sân, sân của tôi, thêm sân, chỉnh sửa sân, chờ duyệt, bảng giá, doanh thu, khách hàng, nhân viên, quản lý trận đấu, chi tiết đặt sân, hồ sơ. Admin có bảy nhóm quản lý đã nêu và các màn duyệt/báo cáo. Nhân viên vào không gian riêng từ đăng nhập/tài khoản, không cần mượn phiên chủ sân.

### 7.2 Các luồng UI chính

| Luồng | Chuỗi màn hình | Trạng thái cần thể hiện |
| --- | --- | --- |
| Đặt sân | Chi tiết sân → chọn giờ → thông tin đặt → thanh toán → lịch đặt → chi tiết | Thiếu thông tin, trùng giờ, chờ chứng từ, pending, hết hạn, approved |
| Hủy | Chi tiết → điều kiện hủy → lý do/thông tin nhận hoàn → gửi → theo dõi | Đủ điều kiện, quá hạn, chờ phản hồi, từ chối, hoàn chờ/đã ghi nhận |
| Hồ sơ sân | Danh sách → chỉnh sửa → lưu/gửi → chờ duyệt → admin xử lý | Nháp, pending, supplement, rejected, approved, suspended |
| Nhân viên | Đăng nhập riêng → lịch/ca → chi tiết → điểm danh/thu | Chỉ xem, đủ quyền, ngoài phạm vi, bị thu hồi quyền |
| Giải đấu | Khám phá → chi tiết → đăng ký → thanh toán lệ phí → hoàn tất → vé/lịch đấu | Hết chỗ, thiếu đồng đội, thanh toán mô phỏng, vé hủy |
| Kiểm duyệt | Danh sách → hồ sơ/nội dung → quyết định → xác nhận → lịch sử | Giữ/ẩn hoặc duyệt/bổ sung/từ chối; xử lý sai phiên bản |

### 7.3 Quy ước UI và nghiệm thu

Giữ xanh lá làm màu thương hiệu, chữ có dấu và số tiền nhất quán. Trạng thái không chỉ dựa màu mà có nhãn; nút phá hủy có xác nhận phù hợp. Lỗi biểu mẫu gắn trường, giữ dữ liệu người dùng nhập; loading/empty/error tách biệt. Màn hình hẹp cho phép nội dung xuống dòng thay vì che nút.

Ảnh minh chứng trong báo cáo lấy từ kết quả test/emulator sẵn có; widget test có thể dùng ảnh giả nên vùng ảnh trống không phải chứng nhận asset thực tế. Không coi screenshot test là nghiệm thu camera, file picker, microphone hoặc GPS trên điện thoại thật. Phụ lục sơ đồ PDF dùng khổ A3 để giữ chữ và quan hệ đọc được; phần báo cáo chữ dùng khổ Letter. Có thể xuất riêng từng trang từ draw.io theo khổ trường yêu cầu.

## 8 Truy vết và kế hoạch kiểm thử

### 8.1 Bảng truy vết

| Yêu cầu | Use case | Source đại diện | Test đại diện | Sequence |
| --- | --- | --- | --- | --- |
| FR05–FR09 | UC02 UC03 | demo_session, demo_management, customer_checkout_screen | booking_test, customer_checkout_test | SQ01 SQ02 |
| FR10–FR11 | UC04 UC05 | demo_management, customer_cancellation_screen | cancellation_policy_test, customer_cancellation_test | SQ03 |
| FR13–FR15 | UC06 UC07 | demo_facilities_session, facility_pending_screen | facilities_test, facility_pending_test | SQ04 |
| FR16–FR17 | UC08 | demo_calendar_session, demo_facility_tariffs_session | calendar_test, tariff_test, facility_tariffs_test | SQ01 phụ thuộc |
| FR18–FR20 | UC09 UC10 | demo_employee_access_session, demo_shifts_session | employee_access_test, employee_facility_scope_test | SQ05 |
| FR21–FR24 | UC11 UC12 UC13 | demo_activities_session, demo_workflow_session, demo_matches_session | activities_test, customer_tournament_checkout_test, matches_test | SQ06 |
| FR25–FR26 | UC14 | demo_play_groups_session, demo_session, customer_forum_views | group_membership_test, customer_forum_views_test | Không tách riêng lần 1 |
| FR12 FR29 | UC15 | demo_reviews_session, admin_management_screen | reviews_test, admin_management_figma_test | Không tách riêng lần 1 |
| FR27 FR28 FR30 | UC16 | session_store, demo_cashflow, admin_report_export | persistence_test, cashflow_test, admin_system_report_test | Store trong SQ01–SQ06 |

Tên source/test trong bảng là tên file `.dart`, nằm trong lib hoặc test tương ứng. Bảng thể hiện liên hệ thiết kế, không khẳng định tất cả file này đã chạy lại trong lượt làm tài liệu.

### 8.2 Kịch bản demo và nghiệm thu thủ công

| Mã | Kịch bản | Kết quả mong đợi |
| --- | --- | --- |
| AT01 | Minh Phát đăng nhập xem lịch; đổi sang Tấn Đạt | Mỗi người chỉ xem lịch/vé của mình |
| AT02 | Đặt một giờ trống, thử đặt lại giờ đó | Lần thứ hai không tạo lịch trùng |
| AT03 | Hoàn thành checkout với ảnh mẫu | Hiển thị chờ xác nhận, chưa approved |
| AT04 | Chủ sân duyệt, khách mở lại lịch | Trên cùng thiết bị, trạng thái approved được giữ |
| AT05 | Dùng đồng hồ giả kiểm tra deadline | Hết hạn chặn gửi; không báo hoàn tiền tự động |
| AT06 | Gửi yêu cầu hủy đúng hạn | Requested; lịch chưa hủy; tiền dự kiến đúng |
| AT07 | Gửi hủy quá hạn | Chặn gửi, giải thích hạn; lịch vẫn hiệu lực |
| AT08 | Chủ sân chấp thuận và ghi nhận hoàn mẫu | Hủy/hoàn có trạng thái riêng; không ghi nhận hai lần |
| AT09 | Sửa hồ sơ pending rồi admin duyệt bản cũ | Bản cũ bị chặn bởi revision |
| AT10 | Admin yêu cầu bổ sung | Chủ sân thấy lý do và có thể gửi lại |
| AT11 | Nhân viên schedule đăng nhập | Xem lịch/ca, không được điểm danh hoặc thu |
| AT12 | Nhân viên đầy đủ quyền vào cơ sở ngoài phạm vi | Bị chặn dù biết mã lịch |
| AT13 | Thu hồi quyền khi nhân viên có phiên cũ | Thao tác tiếp theo bị chặn |
| AT14 | Phân bổ sân cho giải rồi đặt giờ trùng | Chặn đặt, giải phóng sau hủy đúng luồng |
| AT15 | Đăng ký giải và thanh toán mẫu | Có vé/mã đăng ký, nhãn mô phỏng |
| AT16 | Đổi giá sau khi đã đặt | Giá hợp đồng cũ không thay đổi |
| AT17 | Tắt/mở ứng dụng | Giữ lịch, quyền và quyết định, không seed lại |
| AT18 | Giả lập lỗi ghi store | Hiển thị chưa lưu và nút thử lại |
| AT19 | Màn 320px và cỡ chữ lớn | Không tràn/chồng chữ hoặc mất nút |
| AT20 | Từ chối GPS hoặc mất mạng | Có thông báo/fallback, không làm sập app |

### 8.3 Bằng chứng đã có

Đợt sửa dữ liệu gần nhất có log 91 test liên quan thành công; sau thay đổi cuối nhóm 16 test seed/widget thành công. Hai nhóm có chồng lặp, không cộng thành 107 test khác nhau. Phân tích toàn dự án sau đó còn một lint thông tin về dấu ngoặc trong `integration_test/owner_tabs_device_test.dart:51`; không phải lỗi biên dịch. APK debug đã cài và mở thành công trên emulator-5554.

Chưa chạy lại toàn bộ test suite hoặc toàn bộ integration test trên điện thoại thật trong lượt lập tài liệu. Hình trong phụ lục là bằng chứng tại thời điểm chụp, không chứng minh mọi luồng đều đạt. File `validation_results.json` của bộ tài liệu ghi riêng kết quả kiểm tra SQL/XML/link, không nhập nhằng với kiểm thử ứng dụng.

## 9 Đánh giá lần 1 và công việc tiếp theo

### 9.1 Mức đáp ứng

Source hiện có layout, điều hướng, phân nhóm mã và APK để kiểm thử UI/UX. Tài liệu này bổ sung URD, use case, sequence, ERD/class, deployment, truy vết và kế hoạch nghiệm thu. Mức đáp ứng cuối cùng do giảng viên đánh giá theo rubric; không thể suy ra chắc chắn đạt 40% điểm từ số màn hình hoặc số test.

### 9.2 Việc cần làm trước buổi báo cáo

1. Điền thông tin trường/nhóm và thống nhất tên ứng dụng.
2. Chốt các quy tắc mở, nhất là thẻ sinh viên và hủy/hoàn.
3. Thử APK trên một điện thoại thật, kiểm tra chọn ảnh/PDF, micro và GPS.
4. Quay video ngắn các luồng đặt–duyệt–hủy, duyệt hồ sơ và nhân viên bị giới hạn quyền.
5. Cập nhật README cũ, sửa lint nhỏ và chuẩn bị APK/video dự phòng.
6. Không nhập giấy tờ cá nhân, tài khoản ngân hàng hoặc chứng từ thật vào bản demo.

### 9.3 Lộ trình sau lần 1

Tách repository/service khỏi Session; chọn DB/API; migration dữ liệu; hash mật khẩu và token; scope nhiều chủ sân; giao dịch và chống gửi lặp; kho tệp riêng tư; tích hợp thanh toán sandbox; thông báo thật; kiểm thử bảo mật/đồng thời và release signing. Những mục này là kế hoạch, không phải tính năng đang có.

## 10 Phụ lục tài khoản và nguồn đối chiếu

### 10.1 Tài khoản mẫu

| Vai trò hoặc tên | Đăng nhập | Mật khẩu khởi tạo |
| --- | --- | --- |
| Khách hàng Văn Hùng | 0901234567 hoặc demo@nvh.vn | Demo1234 |
| Nguyễn Minh Anh | 0909000011 | Demo1234 |
| Nguyễn Quốc Bảo | 0909000012 | Demo1234 |
| Trần Hoàng Nam | 0909000013 | Demo1234, tài khoản khóa mẫu |
| Minh Phát | 0909000014 | Demo1234 |
| Tấn Đạt | 0909000015 | Demo1234 |
| Chủ sân Nguyễn Văn Hùng | owner@nvh.demo | Demo1234 |
| Admin Trần Thu Hà | admin@nvh.demo | Demo1234 |
| Nhân viên Trần Minh Hoàng | 0909000001 | Demo1234 |
| Nhân viên chỉ xem Lê Thảo Linh | 0909000002 | Demo1234 |

Nếu tài khoản đã đổi mật khẩu thì tiếp tục dùng mật khẩu đã đổi. Nhân viên dùng không gian nhân viên; không đăng nhập như khách. Tài khoản trùng đã tồn tại được bộ seed giữ nguyên, nên môi trường cũ có thể khác bản cài mới.

### 10.2 Nguồn nội bộ

Source `lib/main.dart`, `lib/auth/demo_session.dart`, `lib/auth/session_store.dart`, các extension nghiệp vụ và model trong `lib/demo`, `lib/booking`. Cấu hình `pubspec.yaml`, `android/app/build.gradle.kts`, `AndroidManifest.xml`. Tài liệu `DEMO_TEST_DATA.md`; log `build/natural-seed-regression.log`, `build/natural-seed-final-tests.log`, `build/report-readiness-analyze.log`; ảnh `build/previews/natural-seed-emulator.png`, `natural-venues-402.png`, `natural-venues-320.png`.

### 10.3 Nguồn công cụ

Draw.io lưu sơ đồ dạng XML chỉnh sửa được: https://www.drawio.com/docs/manual/editor/save-file-formats/ . Link chia sẻ chứa dữ liệu sơ đồ: https://www.drawio.com/docs/manual/export/publish-link/ . Link trong bộ bàn giao mở một bản sao được mã hóa trong URL, không phải file cộng tác đang đồng bộ hoặc file đã đăng lên Drive.

SQL sử dụng SQLite với foreign keys được bật cho từng kết nối: https://www.sqlite.org/foreignkeys.html . Tham khảo trigger: https://www.sqlite.org/lang_createtrigger.html . Các tài liệu công cụ không thay thế yêu cầu môn học.
