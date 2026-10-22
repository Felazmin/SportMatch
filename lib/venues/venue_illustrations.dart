const venueIllustrations = <String, String>{
  'Cầu lông': 'assets/illustrations/venues/badminton.png',
  'Pickleball': 'assets/illustrations/venues/pickleball.png',
  'Bóng đá': 'assets/illustrations/venues/football.png',
  'Bóng đá trong nhà': 'assets/illustrations/venues/futsal.png',
  'Bóng rổ': 'assets/illustrations/venues/basketball.png',
  'Quần vợt': 'assets/illustrations/venues/tennis.png',
  'Bóng bàn': 'assets/illustrations/venues/table-tennis.png',
  'Đa năng': 'assets/illustrations/venues/multisport.png',
};

String venueIllustrationFor(String sport) =>
    venueIllustrations[sport] ?? venueIllustrations['Đa năng']!;
