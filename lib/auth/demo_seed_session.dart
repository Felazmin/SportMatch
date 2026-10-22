part of 'demo_session.dart';

extension DemoSeedSession on DemoSession {
  int get installedDemoSeedVersion => _demoSeedVersion;

  // Build on a copy and run the full persistence validator before committing.
  // No login changes, partial writes, or replacement of existing records.
  bool installDemoFixtures(String photo, {required String proof}) {
    if (_demoSeedVersion >= demoSeedVersion) return false;
    decodeProof(photo);
    decodeProof(proof);
    final candidate = DemoSession(now: _now);
    candidate._discoveryVenues = _discoveryVenues;
    try {
      candidate._restore(_snapshot());
      if (candidate._demoSeedVersion < 1) candidate._seedFixtures(photo, proof);
      candidate._naturalizeDemoFixtures(proof);
      candidate._demoSeedVersion = demoSeedVersion;
      _restore(candidate._snapshot());
    } finally {
      candidate.dispose();
    }
    if (initialized) _changed();
    return true;
  }

  void _seedFixtures(String photo, String sampleProof) {
    final day = bookingDay(now);
    final created = day.subtract(const Duration(days: 7));
    String id(String prefix, int n) => '$prefix${n.toString().padLeft(4, '0')}';
    int nextId(Iterable<String> ids, String prefix) =>
        ids.fold<int>(
          0,
          (n, value) => int.parse(value.substring(prefix.length)) > n
              ? int.parse(value.substring(prefix.length))
              : n,
        ) +
        1;
    for (final e in demoAdditionalPlayers.entries) {
      if (['0909000014', '0909000015'].contains(e.key)) continue;
      if (_registered.containsKey(e.key)) continue;
      _registered[e.key] = (
        user: DemoUser(name: e.value, identifier: e.key, registeredAt: created),
        password: demoSeedPassword,
      );
      if (e.key == '0909000013') _operations.blocked.add(e.key);
    }
    final addedFacilities = <DemoFacility>[];
    for (final scenario in demoFacilityScenarios) {
      if (_facilities.length >= 20) break;
      if (_facilities.any((f) => f.draft.name == scenario.name)) continue;
      final profile = FacilityProfile(
        name: scenario.name,
        sport: scenario.sport,
        address: scenario.address,
        city: 'TP. Hồ Chí Minh',
        district: scenario.district,
        phone: DemoSession.phone,
        ownerName: 'Nguyễn Văn Hùng',
        courtCount: 3,
        openHour: 6,
        closeHour: 22,
        baseRate: 110000,
        description: 'Dữ liệu kiểm thử tham khảo tên và địa chỉ sân có thật. Ảnh, giá, hồ sơ, trạng thái duyệt và chứng từ là dữ liệu mẫu, không đại diện cho cơ sở thực tế.',
        cancelPolicy: 'Hủy trước ít nhất 2 giờ: phí 5%, hoàn tiền sau khi chủ sân chấp thuận.',
        photo: photo,
        legalProof: sampleProof,
        amenities: {'Bãi xe', 'Nước uống', 'Wi-Fi'},
      );
      final f = DemoFacility(
        id: id('CS', _nextFacility++),
        owner: '__owner__',
        draft: profile,
        updated: created,
        state: scenario.state,
        published: scenario.state == 'approved' ? profile : null,
        note: scenario.state == 'rejected'
            ? 'Vui lòng bổ sung ảnh giấy phép rõ nét.'
            : '',
        reviewDecision: scenario.state == 'rejected' ? 'supplement' : '',
      );
      _facilities.add(f);
      if (f.published != null) addedFacilities.add(f);
    }
    for (final phone in [demoManagerPhone, demoViewerPhone]) {
      // A pre-existing phone belongs to the user: never grant it new access.
      if (_operations.employees.any((e) => e.phone == phone) ||
          _operations.employees.length >= 100) {
        continue;
      }
      final employee = DemoEmployee(
        id: id('NS', _operations.nextEmployee++),
        name: phone == demoManagerPhone ? 'Trần Minh Hoàng' : 'Lê Thảo Linh',
        phone: phone,
        job: 'Điều phối',
        active: true,
      );
      _operations.employees.add(employee);
      _employeeAccess[employee.id] = DemoEmployeeAccess(
        password: demoSeedPassword,
        permissions: phone == demoManagerPhone
            ? {'schedule', 'attendance', 'onsite'}
            : {'schedule'},
        revision: 1,
        facilityIds: {'', for (final f in addedFacilities) f.id},
      );
      for (var offset = 0; offset < 4 && _shifts.length < 500; offset++) {
        _shifts.add(
          DemoShift(
            id: id('CA', _nextShift++),
            employeeId: employee.id,
            start: day.add(Duration(days: offset, hours: 8)),
            hours: 8,
          ),
        );
      }
    }
    var bookingId = nextId(_bookings.map((b) => b.id), 'NVH');
    final newBookings = <DemoBooking>[];
    for (var i = 0; i < demoBookingScenarios.length; i++) {
      final scenario = demoBookingScenarios[i];
      final historical = ['completed', 'absent'].contains(scenario);
      var start = day.add(
        Duration(days: historical ? -2 : 1 + i ~/ 4, hours: 8 + (i % 4) * 2),
      );
      // Find a free slot without moving any existing booking or blocked period.
      while (_bookings.any(
            (b) =>
                !b.cancelled &&
                b.facilityId.isEmpty &&
                b.court == 2 &&
                start.isBefore(b.end) &&
                start.add(const Duration(hours: 1)).isAfter(b.start),
          ) ||
          _courtBlocks.any(
            (b) =>
                b.facilityId.isEmpty &&
                b.court == 2 &&
                start.isBefore(b.end) &&
                start.add(const Duration(hours: 1)).isAfter(b.start),
          )) {
        start = start.add(const Duration(days: 1));
      }
      final b = DemoBooking(
        id: id('NVH', bookingId++),
        owner: DemoSession.phone,
        court: 2,
        start: start,
        hours: 1,
        contact: _demoUser.name,
        phone: DemoSession.phone,
        cancellationPolicy: _primaryCancellationPolicy,
      );
      _bookings.add(b);
      newBookings.add(b);
      if (scenario == 'manual-unpaid') continue;
      final p = DemoPayment(
        bookingId: b.id,
        deadline: scenario == 'expired'
            ? now.subtract(const Duration(minutes: 1))
            : (historical
                  ? start.subtract(const Duration(hours: 1))
                  : now.add(const Duration(minutes: 15))),
      );
      _payments[b.id] = p;
      if (['awaiting', 'expired', 'cancel-unpaid'].contains(scenario)) {
        p.checkout = true;
      } else {
        p.state = scenario == 'pending'
            ? DemoPaymentState.pending
            : scenario == 'rejected'
            ? DemoPaymentState.rejected
            : DemoPaymentState.approved;
        p.proof = sampleProof;
        p.reference = 'DEMO-${b.id}';
        if (p.state == DemoPaymentState.approved) {
          p.receivedAt = historical
              ? start.subtract(const Duration(hours: 2))
              : now;
        }
        if (scenario == 'rejected') {
          p.reviewNote = 'Chứng từ chưa rõ, vui lòng gửi lại ảnh thanh toán.';
        }
      }
      if ([
        'cancel-request',
        'cancel-rejected',
        'refund-pending',
        'refunded',
        'cancel-unpaid',
      ].contains(scenario)) {
        p.cancellation = scenario == 'cancel-rejected'
            ? DemoCancellationState.rejected
            : ['refund-pending', 'refunded'].contains(scenario)
            ? DemoCancellationState.accepted
            : DemoCancellationState.requested;
        p.cancellationReason =
            'Tôi có việc đột xuất nên không thể đến sân đúng giờ.';
        p.cancellationRequestedAt = now;
        p.cancellationEstimate = scenario == 'cancel-unpaid'
            ? 0
            : b.cancellationPolicy.refundAmount(b.total, b.start, now);
        p.refundDestination = const DemoRefundDestination.bank(
          bank: 'Ngân hàng mô phỏng',
          account: '0000000000',
          holder: 'NGUYEN VAN HUNG',
        );
        if (scenario == 'cancel-rejected') {
          p.cancellationNote =
              'Cần xác minh thông tin trước khi xử lý yêu cầu.';
        }
        if (p.cancellation == DemoCancellationState.accepted) {
          b.cancelled = true;
          p.refund = scenario == 'refunded'
              ? DemoRefundState.recorded
              : DemoRefundState.pending;
          p.refundAmount = p.cancellationEstimate;
          if (scenario == 'refunded') {
            p.refundReference = 'DEMO-REFUND-${b.id}';
            p.refundProof = sampleProof;
            p.refundRecordedAt = now;
          }
        }
      }
      if (scenario == 'completed') b.attendance = DemoAttendance.completed;
      if (scenario == 'absent') b.attendance = DemoAttendance.absent;
      if (scenario == 'onsite') {
        p.atVenue = true;
        p.proof = '';
      }
    }
    for (final f in addedFacilities) {
      final profile = f.published!;
      final b = DemoBooking(
        id: id('NVH', bookingId++),
        owner: '0909000011',
        court: 1,
        start: day.add(const Duration(days: 1, hours: 10)),
        hours: 1,
        contact: _registered['0909000011']!.user.name,
        phone: '0909000011',
        facilityId: f.id,
        venueName: profile.name,
        venueAddress: profile.address,
        sport: profile.sport,
        rate: profile.baseRate,
      );
      _bookings.add(b);
      _payments[b.id] = DemoPayment(
        bookingId: b.id,
        deadline: now.add(const Duration(minutes: 15)),
      );
      if (_courtBlocks.length < 500) {
        _courtBlocks.add(
          DemoCourtBlock(
            id: id('KB', _nextBlock++),
            facilityId: f.id,
            court: 3,
            start: day.add(const Duration(days: 1, hours: 8)),
            hours: 2,
            reason: 'Bảo trì mặt sân',
          ),
        );
      }
    }
    final completed = newBookings.firstWhere(
      (b) => b.attendance == DemoAttendance.completed,
    );
    _reviews.add(
      DemoVenueReview(
        bookingId: completed.id,
        owner: DemoSession.phone,
        author: _demoUser.name,
        stars: 4,
        message: 'Sân sạch sẽ, nhân viên hỗ trợ nhiệt tình. Tôi sẽ quay lại.',
        created: now,
      ),
    );
    _disputes.add(
      DemoDispute(
        id: id('KN', nextId(_disputes.map((d) => d.id), 'KN')),
        owner: DemoSession.phone,
        bookingId: completed.id,
        subject: 'Kiểm tra phí dịch vụ',
        message: 'Nhờ chủ sân đối chiếu giúp khoản phí trong lịch đặt này.',
        created: now,
      )..response = 'Chủ sân đã tiếp nhận và đang đối chiếu chứng từ.',
    );
    _favorites.putIfAbsent(DemoSession.phone, () => {}).add('cong-thuong');
    _paymentMethods.putIfAbsent(
      DemoSession.phone,
      () => [
        DemoPaymentMethod(provider: 'Visa', last4: '8829', isDefault: true),
      ],
    );
    _ownerVerification ??= DemoOwnerVerification(
      name: 'Nguyễn Văn Hùng',
      phone: DemoSession.phone,
      proof: sampleProof,
      state: 'pending',
      created: created,
      updated: now,
      revision: 1,
    );
    _seedCommunity(photo, created, id);
    _seedActivities(created, sampleProof, id);
    _seedFinancialHistory(sampleProof, id, bookingId);
    if (addedFacilities.isNotEmpty) {
      final f = addedFacilities.first;
      _facilityTariffs[f.id] = FacilityTariffPlan(
        facilityId: f.id,
        revision: 1,
        facilityRevision: f.revision,
        state: 'pending',
        draft: [
          FacilityTariffBand(
            court: 1,
            weekend: false,
            fromHour: 18,
            toHour: 22,
            rate: 130000,
            effectiveFrom: day,
          ),
        ],
      );
    }
    if (_operations.audit.length < 1000) {
      _operations.audit.add(
        DemoAuditEntry(
          actor: '__admin__',
          action: 'Nạp bộ dữ liệu kiểm thử; không phát sinh giao dịch thật.',
          created: now,
        ),
      );
    }
  }

  void _seedCommunity(
    String photo,
    DateTime created,
    String Function(String, int) id,
  ) {
    DemoPlayGroup? publicGroup;
    for (final state in [
      'approved',
      'pending',
      'rejected',
      'draft',
      'suspended',
    ]) {
      if (_playGroups.length >= 100) break;
      final name = demoGroupNames[state]!;
      if (_playGroups.any(
        (g) => venueSearchText(g.name) == venueSearchText(name),
      )) {
        continue;
      }
      final g = DemoPlayGroup(
        id: id('NC', _nextPlayGroup++),
        owner: '__owner__',
        name: name,
        sport: 'badminton',
        description: 'Nhóm giao lưu cầu lông, chào đón người mới và ưu tiên tinh thần thể thao, an toàn.',
        created: created,
        updated: now,
        state: state,
        revision: 3,
        photo: photo,
        requiresApproval: true,
        note: ['rejected', 'suspended'].contains(state)
            ? 'Vui lòng bổ sung quy tắc ứng xử và thông tin quản trị viên.'
            : '',
        reviewDecision: state == 'rejected' ? 'supplement' : '',
      );
      _playGroups.add(g);
      if (state == 'approved') publicGroup = g;
    }
    if (publicGroup != null) {
      for (final member in [DemoSession.phone, '0909000011']) {
        if (_groupRequests.length >= 500) break;
        final approved = member == '0909000011';
        _groupRequests.add(
          DemoGroupRequest(
            groupId: publicGroup.id,
            member: member,
            state: approved ? 'approved' : 'pending',
            created: now,
            updated: now,
            revision: 1,
          ),
        );
        if (approved) _groups.putIfAbsent(member, () => {}).add(publicGroup.id);
      }
    }
    for (var i = 0; i < 3; i++) {
      final postOwner = [DemoSession.phone, '0909000011', '0909000012'][i];
      final post = DemoPost(
        id: id('BD', _nextPost++),
        owner: postOwner,
        author: postOwner == DemoSession.phone
            ? _demoUser.name
            : _registered[postOwner]!.user.name,
        groupId: 'public',
        created: now,
        message: i == 0
            ? 'Cuối tuần này mình tìm thêm hai bạn giao lưu cầu lông. Ai tham gia cùng không?'
            : i == 1
            ? 'Mọi người có thể chia sẻ kinh nghiệm chọn vợt cho người mới bắt đầu không?'
            : 'Mình đang tìm nhóm chơi cầu lông vào buổi tối ở Tân Phú.',
      );
      _posts.add(post);
      if (i == 2) _operations.hiddenPosts.add(post.id);
    }
    var n =
        _expenses.fold<int>(
          0,
          (n, e) => int.parse(e.id.substring(2)) > n
              ? int.parse(e.id.substring(2))
              : n,
        ) +
        1;
    _expenses.add(
      DemoExpense(
        id: id('CP', n++),
        owner: DemoSession.phone,
        title: 'Chi phí buổi giao lưu cầu lông',
        amount: 600000,
        names: [
          _demoUser.name,
          'Nguyễn Minh Anh',
          'Nguyễn Quốc Bảo',
          'Minh Phát',
        ],
        created: now,
      ),
    );
    n =
        _enrollments.fold<int>(
          0,
          (n, e) => int.parse(e.id.substring(2)) > n
              ? int.parse(e.id.substring(2))
              : n,
        ) +
        1;
    _enrollments.add(
      DemoEnrollment(
        id: id('HL', n),
        owner: DemoSession.phone,
        courseId: 'basic',
        start: demoCourses.first.start(now),
      ),
    );
    n =
        _tickets.fold<int>(
          0,
          (n, e) => int.parse(e.id.substring(2)) > n
              ? int.parse(e.id.substring(2))
              : n,
        ) +
        1;
    _tickets.add(
      DemoSupportTicket(
        id: id('HT', n),
        owner: DemoSession.phone,
        subject: 'Hỗ trợ cập nhật tài khoản',
        message:
            'Tôi cần hỗ trợ cập nhật số điện thoại liên hệ trong tài khoản.',
        created: now,
      ),
    );
  }

  void _seedActivities(
    DateTime created,
    String proof,
    String Function(String, int) id,
  ) {
    for (final state in [
      'approved',
      'pending',
      'rejected',
      'draft',
      'suspended',
    ]) {
      if (_courtTypes.length >= 100) break;
      final name = demoCourtTypeNames[state]!;
      if (_courtTypes.any(
        (t) => venueSearchText(t.name) == venueSearchText(name),
      )) {
        continue;
      }
      _courtTypes.add(
        DemoCourtType(
          id: id('LS', _nextCourtType++),
          name: name,
          sport: 'Cầu lông',
          description: 'Sân cầu lông tiêu chuẩn, kích thước 13,4 × 6,1 m.',
          created: created,
          updated: now,
          state: state,
          revision: 3,
          note: ['rejected', 'suspended'].contains(state)
              ? 'Vui lòng bổ sung kích thước sân và thông tin mặt sân.'
              : '',
          reviewDecision: state == 'rejected' ? 'supplement' : '',
        ),
      );
    }
    final approved = <DemoEvent>[];
    var activityIndex = 0;
    for (final state in [
      'approved',
      'approved',
      'pending',
      'rejected',
      'draft',
      'suspended',
    ]) {
      if (_activities.length >= 100) break;
      final kind = approved.length == 1
          ? DemoEventKind.tournament
          : DemoEventKind.social;
      final eventId = id('HD', _nextActivity++);
      var start = bookingDay(now)
          .add(Duration(days: 3 + approved.length, hours: 14));
      while (_bookings.any(
            (b) =>
                !b.cancelled &&
                b.facilityId.isEmpty &&
                b.court == 1 &&
                start.isBefore(b.end) &&
                start.add(const Duration(hours: 2)).isAfter(b.start),
          ) ||
          _courtBlocks.any(
            (b) =>
                b.facilityId.isEmpty &&
                b.court == 1 &&
                start.isBefore(b.end) &&
                start.add(const Duration(hours: 2)).isAfter(b.start),
          )) {
        start = start.add(const Duration(days: 1));
      }
      final event = DemoEvent(
        id: eventId,
        title: demoActivityNames[activityIndex++],
        kind: kind,
        hour: 14,
        durationMinutes: 120,
        capacity: 8,
        fee: kind == DemoEventKind.tournament ? 150000 : 60000,
        description: 'Giao lưu thể thao phong trào, đăng ký theo lịch và đóng phí tham dự. Đây là hoạt động mô phỏng để kiểm thử.',
        scheduledStart: start,
      );
      _activities.add(
        DemoActivity(
          event: event,
          owner: '__owner__',
          created: created,
          updated: now,
          state: state,
          revision: 3,
          note: ['rejected', 'suspended'].contains(state)
              ? 'Vui lòng bổ sung thể lệ và lịch trình hoạt động.'
              : '',
          reviewDecision: state == 'rejected' ? 'supplement' : '',
        ),
      );
      if (state == 'approved') approved.add(event);
      if (state == 'approved' && _courtBlocks.length < 500) {
        _courtBlocks.add(
          DemoCourtBlock(
            id: id('KB', _nextBlock++),
            court: 1,
            start: start,
            hours: 2,
            reason: 'Giữ sân cho hoạt động đã duyệt',
            eventId: event.id,
          ),
        );
      }
    }
    var next =
        _participations.fold<int>(
          0,
          (n, p) => int.parse(p.id.substring(2)) > n
              ? int.parse(p.id.substring(2))
              : n,
        ) +
        1;
    for (final event in approved) {
      final tickets = <DemoParticipation>[];
      for (final owner in [DemoSession.phone, '0909000011']) {
        final tournament = event.kind == DemoEventKind.tournament;
        final p = DemoParticipation(
          id: id('VE', next++),
          owner: owner,
          eventId: event.id,
          eventSnapshot: event,
          start: event.scheduledStart!,
          quantity: 1,
          contact: owner == DemoSession.phone
              ? _demoUser.name
              : _registered[owner]!.user.name,
          phone: owner,
          team: tournament
              ? (owner == DemoSession.phone
                    ? 'Đôi Văn Hùng - Tấn Đạt'
                    : 'Đôi Minh Anh - Minh Phát')
              : '',
          partner: tournament
              ? (owner == DemoSession.phone ? 'Tấn Đạt' : 'Minh Phát')
              : '',
          registration: tournament
              ? const DemoTournamentRegistration(
                  birthYear: 1995,
                  email: 'player@example.test',
                  level: '3.5',
                  accepted: true,
                )
              : null,
        );
        _participations.add(p);
        tickets.add(p);
        _payments[p.id] =
            DemoPayment(
                bookingId: p.id,
                deadline: now.add(const Duration(minutes: 30)),
              )
              ..state = DemoPaymentState.approved
              ..proof = proof
              ..reference = 'DEMO-${p.id}'
              ..receivedAt = now;
      }
      if (event.kind == DemoEventKind.tournament && _matches.length < 1000) {
        _matches.add(
          DemoMatch(
            id: id('TD', _nextMatch++),
            first: tickets[0].id,
            second: tickets[1].id,
            start: event.scheduledStart!,
            court: 1,
          ),
        );
      }
    }
  }

  void _seedFinancialHistory(
    String proof,
    String Function(String, int) id,
    int nextBooking,
  ) {
    // Completed services provide a linked basis for local revenue reports.
    for (var i = 0; i < 3; i++) {
      var start = bookingDay(now)
          .subtract(Duration(days: 3 + i))
          .add(const Duration(hours: 10));
      while (_bookings.any(
            (b) =>
                !b.cancelled &&
                b.facilityId.isEmpty &&
                b.court == 3 &&
                start.isBefore(b.end) &&
                start.add(const Duration(hours: 1)).isAfter(b.start),
          ) ||
          _courtBlocks.any(
            (b) =>
                b.facilityId.isEmpty &&
                b.court == 3 &&
                start.isBefore(b.end) &&
                start.add(const Duration(hours: 1)).isAfter(b.start),
          )) {
        start = start.subtract(const Duration(days: 1));
      }
      final owner = i == 0 ? DemoSession.phone : '0909000012';
      final b = DemoBooking(
        id: id('NVH', nextBooking++),
        owner: owner,
        court: 3,
        start: start,
        hours: 1,
        contact: i == 0 ? _demoUser.name : _registered[owner]!.user.name,
        phone: owner,
      )..attendance = DemoAttendance.completed;
      _bookings.add(b);
      _payments[b.id] = DemoPayment(bookingId: b.id, deadline: start)
        ..state = DemoPaymentState.approved
        ..proof = proof
        ..reference = 'DEMO-${b.id}'
        ..receivedAt = start.subtract(const Duration(hours: 1));
      if (i == 1) {
        _reviews.add(
          DemoVenueReview(
            bookingId: b.id,
            owner: owner,
            author: b.contact,
            stars: 2,
            message: 'Sân khá đông vào buổi tối, mong chủ sân cải thiện việc sắp xếp lịch.',
            created: b.end,
            hidden: true,
            reason: 'Tạm ẩn để đối chiếu nội dung phản ánh.',
            moderatedAt: now,
            revision: 1,
          ),
        );
      }
    }
    if (_payoutAccount != null || _payouts.isNotEmpty) return;
    _payoutAccount = const DemoBankAccount(
      bank: 'Ngân hàng mô phỏng - không chuyển tiền thật',
      holder: 'NGUYEN VAN HUNG',
      number: '0000000000',
      revision: 1,
    );
    for (final state in ['pending', 'recorded', 'rejected']) {
      if (_payouts.length >= 500) break;
      _payouts.add(
        DemoPayout(
          id: id('CT', _nextPayout++),
          amount: 10000,
          account: _payoutAccount!,
          created: now,
          updated: now,
          state: state,
          revision: state == 'pending' ? 0 : 1,
          reference: state == 'recorded' ? 'DEMO-PAYOUT-RECORDED' : '',
          proof: state == 'recorded' ? proof : '',
          note: state == 'rejected'
              ? 'Chứng từ chưa hợp lệ, vui lòng kiểm tra lại.'
              : '',
        ),
      );
    }
  }

  void _naturalizeDemoFixtures(String proof) {
    final data = jsonDecode(_snapshot()) as Map<String, dynamic>;
    final replacements = Map<String, String>.from(demoNaturalText);
    String reserveName(String proposed, Set<String> used) {
      var result = proposed, suffix = 2;
      while (!used.add(venueSearchText(result))) {
        result = '$proposed (${suffix++})';
      }
      return result;
    }

    final groupNames = (data['playGroups'] as List)
        .map((g) => g['name'] as String)
        .where((name) => !name.startsWith('Hoi cau long DEMO - '))
        .map(venueSearchText)
        .toSet();
    for (final entry in demoGroupNames.entries) {
      replacements['Hoi cau long DEMO - ${entry.key}'] = reserveName(
        entry.value,
        groupNames,
      );
    }
    final typeNames = (data['courtTypes'] as List)
        .map((t) => t['name'] as String)
        .where((name) => !name.startsWith('Loai san DEMO - '))
        .map(venueSearchText)
        .toSet();
    for (final entry in demoCourtTypeNames.entries) {
      replacements['Loai san DEMO - ${entry.key}'] = reserveName(
        entry.value,
        typeNames,
      );
    }
    final titles = (data['activities'] as List)
        .map((a) => a['event']['title'] as String)
        .where(
          (name) => !RegExp(r'^DEMO (Giai dau|Giao luu) HD\d+$').hasMatch(name),
        )
        .map(venueSearchText)
        .toSet();
    var index = 0;
    for (final a in data['activities'] as List) {
      final title = a['event']['title'] as String;
      if (RegExp(r'^DEMO (Giai dau|Giao luu) HD\d+$').hasMatch(title)) {
        replacements[title] = reserveName(
          demoActivityNames[index++ % demoActivityNames.length],
          titles,
        );
      }
    }
    final facilitiesByOldName = {
      for (final scenario in [
        ...demoFacilityScenarios,
        ...demoLegacyFacilityAliases,
      ])
        scenario.legacyName: scenario,
    };
    void updateFacilityProfile(Map<String, dynamic> profile) {
      final scenario = facilitiesByOldName[profile['name']];
      if (scenario == null) return;
      profile['name'] = scenario.name;
      // Leave an address manually edited since v1 intact.
      if ([
        '96 Che Lan Vien - du lieu kiem thu',
        '96 Chế Lan Viên, P. Tây Thạnh, Tân Phú',
      ].contains(profile['address'])) {
        profile['address'] = scenario.address;
        profile['district'] = scenario.district;
      }
    }

    for (final facility in data['facilities'] as List) {
      updateFacilityProfile(facility['draft'] as Map<String, dynamic>);
      if (facility['published'] != null) {
        updateFacilityProfile(facility['published'] as Map<String, dynamic>);
      }
    }
    for (final form in data['facilityFormDrafts'] as List) {
      updateFacilityProfile(form['fields'] as Map<String, dynamic>);
    }
    for (final booking in data['bookings'] as List) {
      final scenario = facilitiesByOldName[booking['venueName']];
      if (scenario != null) {
        booking['venueName'] = scenario.name;
        if ([
          '96 Che Lan Vien - du lieu kiem thu',
          '96 Chế Lan Viên, P. Tây Thạnh, Tân Phú',
        ].contains(booking['venueAddress'])) {
          booking['venueAddress'] = scenario.address;
        }
      }
    }
    for (final ticket in data['participations'] as List) {
      if (ticket['partner'] == 'Dong doi demo' &&
          ticket['owner'] == '0909000011') {
        ticket['partner'] = 'Minh Phát';
      }
      final registration = ticket['registration'] as Map<String, dynamic>?;
      if (registration?['email'] == 'player@example.test') {
        registration!['email'] = ticket['owner'] == DemoSession.phone
            ? 'vanhung@example.test'
            : 'minhanh@example.test';
      }
    }
    // Restrict changes to presentation fields, never credentials, IDs or amounts.
    const fields = {
      'name',
      'author',
      'contact',
      'ownerName',
      'city',
      'district',
      'description',
      'cancelPolicy',
      'note',
      'reviewNote',
      'cancellationReason',
      'cancellationNote',
      'reason',
      'message',
      'response',
      'subject',
      'title',
      'action',
      'team',
      'partner',
      'bank',
      'holder',
      'names',
    };
    dynamic transform(dynamic value, [String? key]) {
      if (value is Map<String, dynamic>) {
        return value.map((k, v) => MapEntry(k, transform(v, k)));
      }
      if (value is List) return value.map((v) => transform(v, key)).toList();
      if (value is String && fields.contains(key)) {
        if (key == 'team' && RegExp(r'^Doi DEMO 0\d{9}$').hasMatch(value)) {
          return value.endsWith(DemoSession.phone)
              ? 'Đôi Văn Hùng - Tấn Đạt'
              : 'Đôi Minh Anh - Minh Phát';
        }
        return replacements[value] ?? value;
      }
      return value;
    }

    _restore(jsonEncode(transform(data)));
    for (final phone in ['0909000014', '0909000015']) {
      // Do not attach fixture histories to a pre-existing customer's account.
      if (_registered.containsKey(phone)) continue;
      _registered[phone] = (
        user: DemoUser(
          name: demoAdditionalPlayers[phone]!,
          identifier: phone,
          registeredAt: now,
        ),
        password: demoSeedPassword,
      );
      _seedNamedPlayerHistory(phone, proof);
    }
  }

  void _seedNamedPlayerHistory(String phone, String proof) {
    var next =
        _bookings.fold<int>(
          0,
          (n, b) => int.parse(b.id.substring(3)) > n
              ? int.parse(b.id.substring(3))
              : n,
        ) +
        1;
    for (var i = 0; i < 2; i++) {
      var start = bookingDay(now).add(
        Duration(days: i == 0 ? 1 : -1, hours: phone.endsWith('14') ? 16 : 18),
      );
      final delta = i == 0 ? const Duration(days: 1) : const Duration(days: -1);
      while (_bookings.any(
            (b) =>
                !b.cancelled &&
                b.facilityId.isEmpty &&
                b.court == 3 &&
                start.isBefore(b.end) &&
                start.add(const Duration(hours: 1)).isAfter(b.start),
          ) ||
          _courtBlocks.any(
            (b) =>
                b.facilityId.isEmpty &&
                b.court == 3 &&
                start.isBefore(b.end) &&
                start.add(const Duration(hours: 1)).isAfter(b.start),
          )) {
        start = start.add(delta);
      }
      final b = DemoBooking(
        id: 'NVH${(next++).toString().padLeft(4, '0')}',
        owner: phone,
        court: 3,
        start: start,
        hours: 1,
        contact: _registered[phone]!.user.name,
        phone: phone,
        rate: _operations.published.rateAt(3, start),
        cancellationPolicy: _primaryCancellationPolicy,
      );
      if (i == 1) b.attendance = DemoAttendance.completed;
      _bookings.add(b);
      _payments[b.id] = DemoPayment(bookingId: b.id, deadline: start)
        ..state = DemoPaymentState.approved
        ..proof = proof
        ..reference = 'DEMO-${b.id}'
        ..receivedAt = i == 0 ? now : start.subtract(const Duration(hours: 1));
    }
  }
}
