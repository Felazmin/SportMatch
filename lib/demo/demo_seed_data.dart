// Local demonstration fixtures only. Never use these credentials in production.
const demoSeedVersion = 2;
const demoSeedPassword = 'Demo1234';
const demoManagerPhone = '0909000001';
const demoViewerPhone = '0909000002';
const demoAdditionalPlayers = {
  '0909000011': 'Nguyễn Minh Anh',
  '0909000012': 'Nguyễn Quốc Bảo',
  '0909000013': 'Trần Hoàng Nam',
  '0909000014': 'Minh Phát',
  '0909000015': 'Tấn Đạt',
};

const demoFacilityScenarios = [
  (
    name: 'Sân cầu lông Phú Thọ',
    sport: 'Cầu lông',
    state: 'approved',
    legacyName: 'San Cau Long K99 - DEMO',
    address: '219 Lý Thường Kiệt',
    district: 'Quận 11',
  ),
  (
    name: 'Pickoland Thảo Điền',
    sport: 'Pickleball',
    state: 'approved',
    legacyName: 'Pickleball Quan 7 - DEMO',
    address: '188/A6 Nguyễn Văn Hưởng',
    district: 'Thủ Đức',
  ),
  (
    name: 'Sân cầu lông Tân Việt',
    sport: 'Cầu lông',
    state: 'pending',
    legacyName: 'San Tan Phu cho duyet - DEMO',
    address: '234 Bình Long',
    district: 'Tân Phú',
  ),
  (
    name: 'Sân bóng đá Thăng Long',
    sport: 'Bóng đá',
    state: 'rejected',
    legacyName: 'San can bo sung - DEMO',
    address: '2 Phan Thúc Duyện',
    district: 'Tân Bình',
  ),
  (
    name: 'Sân tennis Kỳ Hòa 2',
    sport: 'Quần vợt',
    state: 'draft',
    legacyName: 'San ban nhap - DEMO',
    address: '138A Sư Vạn Hạnh',
    district: 'Quận 10',
  ),
];

const demoGroupNames = {
  'approved': 'Hội cầu lông Tân Phú',
  'pending': 'Câu lạc bộ Cầu lông Bình Thạnh',
  'rejected': 'Hội cầu lông Thủ Đức',
  'draft': 'Cầu lông buổi sáng Tân Bình',
  'suspended': 'Nhóm cầu lông cuối tuần Quận 11',
};

// Earlier UI walkthroughs used this placeholder before the v1 fixture pack.
const demoLegacyFacilityAliases = [
  (
    name: 'Sân cầu lông Lan Minh',
    sport: 'Cầu lông',
    state: 'pending',
    legacyName: 'Sân Cầu Lông K99',
    address: '60 Nguyễn Háo Vĩnh',
    district: 'Tân Phú',
  ),
  (
    name: 'Sân cầu lông Lan Minh',
    sport: 'Cầu lông',
    state: 'pending',
    legacyName: 'Sân cầu lông K99',
    address: '60 Nguyễn Háo Vĩnh',
    district: 'Tân Phú',
  ),
];
const demoCourtTypeNames = {
  'approved': 'Cầu lông tiêu chuẩn',
  'pending': 'Cầu lông thảm PVC',
  'rejected': 'Cầu lông trong nhà',
  'draft': 'Cầu lông ngoài trời',
  'suspended': 'Cầu lông sân gỗ',
};
const demoActivityNames = [
  'Giao lưu cầu lông cuối tuần',
  'Giải cầu lông đôi Sài Gòn mở rộng',
  'Giao lưu cầu lông dành cho người mới',
  'Cầu lông đôi cùng bạn bè',
  'Luyện tập cầu lông buổi chiều',
  'Giao lưu cầu lông cộng đồng',
];

// Exact v1 display strings only; custom values and financial identifiers stay intact.
const demoNaturalText = {
  'Minh Anh demo': 'Nguyễn Minh Anh',
  'Quoc Bao demo': 'Nguyễn Quốc Bảo',
  'Tai khoan bi khoa demo': 'Trần Hoàng Nam',
  'Quan ly san DEMO': 'Trần Minh Hoàng',
  'Nhan vien xem lich DEMO': 'Lê Thảo Linh',
  'Chu san DEMO': 'Nguyễn Văn Hùng',
  'Chủ sân demo': 'Nguyễn Văn Hùng',
  'Admin demo': 'Trần Thu Hà',
  'TP. Ho Chi Minh': 'TP. Hồ Chí Minh',
  'Tan Phu': 'Tân Phú',
  'Co so DEMO de kiem thu. Ho so va chung tu dinh kem la mau, khong co gia tri phap ly.': 'Dữ liệu kiểm thử tham khảo tên và địa chỉ sân có thật. Ảnh, giá, hồ sơ, trạng thái duyệt và chứng từ là dữ liệu mẫu, không đại diện cho cơ sở thực tế.',
  'Huy truoc it nhat 2 gio, phi 5%, hoan sau khi chu san chap thuan.':
      'Hủy trước ít nhất 2 giờ: phí 5%, hoàn tiền sau khi chủ sân chấp thuận.',
  'DEMO: Can bo sung giay phep ro net.':
      'Vui lòng bổ sung ảnh giấy phép rõ nét.',
  'DEMO: Chung tu chua ro, vui long gui lai.':
      'Chứng từ chưa rõ, vui lòng gửi lại ảnh thanh toán.',
  'DEMO: Co viec dot xuat, xin huy lich.':
      'Tôi có việc đột xuất nên không thể đến sân đúng giờ.',
  'DEMO: Can xac minh thong tin yeu cau.':
      'Cần xác minh thông tin trước khi xử lý yêu cầu.',
  'NGAN HANG DEMO': 'Ngân hàng mô phỏng',
  'KHACH HANG DEMO': 'NGUYEN VAN HUNG',
  'DEMO: Bao tri mat san': 'Bảo trì mặt sân',
  'DEMO: San sach, nhan vien ho tro tot.':
      'Sân sạch sẽ, nhân viên hỗ trợ nhiệt tình. Tôi sẽ quay lại.',
  'DEMO: Kiem tra phi dich vu': 'Kiểm tra phí dịch vụ',
  'DEMO: Nho chu san doi chieu khoan phi trong lich dat nay.':
      'Nhờ chủ sân đối chiếu giúp khoản phí trong lịch đặt này.',
  'DEMO: Chu san da tiep nhan va dang doi chieu chung tu.':
      'Chủ sân đã tiếp nhận và đang đối chiếu chứng từ.',
  'Nap bo du lieu kiem thu DEMO v1; khong phat sinh giao dich that.':
      'Nạp bộ dữ liệu kiểm thử; không phát sinh giao dịch thật.',
  'Hoi nhom DEMO giao luu cau long, ton trong va choi an toan.': 'Nhóm giao lưu cầu lông, chào đón người mới và ưu tiên tinh thần thể thao, an toàn.',
  'DEMO: Can bo sung quy tac hoi nhom.':
      'Vui lòng bổ sung quy tắc ứng xử và thông tin quản trị viên.',
  'DEMO: Tim ban giao luu cau long cuoi tuan tai san.': 'Cuối tuần này mình tìm thêm hai bạn giao lưu cầu lông. Ai tham gia cùng không?',
  'DEMO: Chia se kinh nghiem chon vot cho nguoi moi.': 'Mọi người có thể chia sẻ kinh nghiệm chọn vợt cho người mới bắt đầu không?',
  'DEMO: Bai viet da an de thu kiem duyet noi dung.':
      'Mình đang tìm nhóm chơi cầu lông vào buổi tối ở Tân Phú.',
  'DEMO: Chia chi phi buoi choi': 'Chi phí buổi giao lưu cầu lông',
  'Ban choi demo': 'Minh Phát',
  'DEMO: Ho tro tai khoan': 'Hỗ trợ cập nhật tài khoản',
  'DEMO: Can huong dan doi thong tin lien he.':
      'Tôi cần hỗ trợ cập nhật số điện thoại liên hệ trong tài khoản.',
  'DEMO: San tieu chuan, kich thuoc 13.4 x 6.1 m.':
      'Sân cầu lông tiêu chuẩn, kích thước 13,4 × 6,1 m.',
  'DEMO: Can bo sung kich thuoc va mat san.':
      'Vui lòng bổ sung kích thước sân và thông tin mặt sân.',
  'Hoat dong DEMO de kiem thu dang ky, thanh toan va duyet ho so.': 'Giao lưu thể thao phong trào, đăng ký theo lịch và đóng phí tham dự. Đây là hoạt động mô phỏng để kiểm thử.',
  'DEMO: Can bo sung quy tac va lich trinh.':
      'Vui lòng bổ sung thể lệ và lịch trình hoạt động.',
  'DEMO: Giu san cho hoat dong': 'Giữ sân cho hoạt động đã duyệt',
  'Dong doi demo': 'Tấn Đạt',
  'DEMO: Danh gia da an de kiem thu khoi phuc hien thi.':
      'Sân khá đông vào buổi tối, mong chủ sân cải thiện việc sắp xếp lịch.',
  'DEMO: An noi dung de kiem thu.': 'Tạm ẩn để đối chiếu nội dung phản ánh.',
  'NGAN HANG DEMO - KHONG CHUYEN TIEN':
      'Ngân hàng mô phỏng - không chuyển tiền thật',
  'CHU SAN DEMO': 'NGUYEN VAN HUNG',
  'DEMO: Tu choi chung tu kiem thu.':
      'Chứng từ chưa hợp lệ, vui lòng kiểm tra lại.',
};

const demoBookingScenarios = [
  'awaiting',
  'pending',
  'rejected',
  'approved',
  'cancel-request',
  'cancel-rejected',
  'refund-pending',
  'refunded',
  'expired',
  'completed',
  'absent',
  'onsite',
  'cancel-unpaid',
  'manual-unpaid',
];
