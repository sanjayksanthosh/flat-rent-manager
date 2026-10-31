class Building {
  final int? id;
  final String buildingName;
  final String address;
  final String area;
  final String caretakerName;
  final String caretakerPhone;
  final String securityPhone;
  final String createdAt;

  Building({this.id, required this.buildingName, this.address = '', this.area = '', this.caretakerName = '', this.caretakerPhone = '', this.securityPhone = '', String? createdAt})
    : createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id, 'buildingName': buildingName, 'address': address,
    'area': area, 'caretakerName': caretakerName, 'caretakerPhone': caretakerPhone,
    'securityPhone': securityPhone, 'createdAt': createdAt,
  };

  factory Building.fromMap(Map<String, dynamic> m) => Building(
    id: m['id'] as int?, buildingName: m['buildingName'] as String,
    address: (m['address'] as String?) ?? '',
    area: (m['area'] as String?) ?? '',
    caretakerName: (m['caretakerName'] as String?) ?? '',
    caretakerPhone: (m['caretakerPhone'] as String?) ?? '',
    securityPhone: (m['securityPhone'] as String?) ?? '',
    createdAt: m['createdAt'] as String?,
  );
}

class Flat {
  final int? id;
  final int buildingId;
  final String flatNumber;
  final String floor;
  final double monthlyRent;
  final String status;
  final String? buildingName;
  final Map<String, dynamic>? tenant;

  Flat({this.id, required this.buildingId, required this.flatNumber, this.floor = '', this.monthlyRent = 0, this.status = 'vacant', this.buildingName, this.tenant});

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id, 'buildingId': buildingId, 'flatNumber': flatNumber,
    'floor': floor, 'monthlyRent': monthlyRent, 'status': status,
  };

  factory Flat.fromMap(Map<String, dynamic> m) => Flat(
    id: m['id'] as int?, buildingId: m['buildingId'] as int,
    flatNumber: m['flatNumber'] as String, floor: (m['floor'] as String?) ?? '',
    monthlyRent: (m['monthlyRent'] as num?)?.toDouble() ?? 0,
    status: (m['status'] as String?) ?? 'vacant',
    buildingName: m['buildingName'] as String?,
    tenant: m['tenant'] as Map<String, dynamic>?,
  );

  String get statusLabel => status == 'occupied' ? 'Occupied' : 'Vacant';
}

class Tenant {
  final int? id;
  final String name;
  final String phone;
  final String phone2;
  final String ksebNo;
  final String address;
  final String idProof;
  final List<Map<String, String>> documents;
  final List<Map<String, dynamic>> amenities;
  final List<dynamic>? leases;

  Tenant({this.id, required this.name, required this.phone, this.phone2 = '', this.ksebNo = '', this.address = '', this.idProof = '', this.documents = const [], this.amenities = const [], this.leases});

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id, 'name': name, 'phone': phone, 'phone2': phone2, 'ksebNo': ksebNo, 'address': address, 'idProof': idProof, 'documents': documents, 'amenities': amenities,
  };

  factory Tenant.fromMap(Map<String, dynamic> m) => Tenant(
    id: m['id'] as int?, name: m['name'] as String, phone: m['phone'] as String,
    phone2: (m['phone2'] as String?) ?? '',
    ksebNo: (m['ksebNo'] as String?) ?? '',
    address: (m['address'] as String?) ?? '',
    idProof: (m['idProof'] as String?) ?? '',
    documents: (m['documents'] as List<dynamic>?)?.map((e) => Map<String, String>.from(e as Map)).toList() ?? [],
    amenities: (m['amenities'] as List<dynamic>?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [],
    leases: m['leases'] as List<dynamic>?,
  );
}

class Lease {
  final int? id;
  final int tenantId;
  final int flatId;
  final String leaseStart;
  final String leaseEnd;
  final double monthlyRent;
  final int advanceMonths;
  final double securityDeposit;
  final String? moveOutDate;
  final String? tenantName;
  final String? tenantPhone;
  final String? tenantAddress;
  final String? flatNumber;
  final String? buildingName;
  final int? buildingId;

  Lease({this.id, required this.tenantId, required this.flatId, required this.leaseStart, required this.leaseEnd, this.monthlyRent = 0, this.advanceMonths = 0, this.securityDeposit = 0, this.moveOutDate, this.tenantName, this.tenantPhone, this.tenantAddress, this.flatNumber, this.buildingName, this.buildingId});

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id, 'tenantId': tenantId, 'flatId': flatId,
    'leaseStart': leaseStart, 'leaseEnd': leaseEnd, 'monthlyRent': monthlyRent,
    'advanceMonths': advanceMonths, 'securityDeposit': securityDeposit,
    if (tenantName != null) 'tenantName': tenantName,
    if (flatNumber != null) 'flatNumber': flatNumber,
    if (buildingName != null) 'buildingName': buildingName,
    if (buildingId != null) 'buildingId': buildingId,
  };

  factory Lease.fromMap(Map<String, dynamic> m) => Lease(
    id: m['id'] as int?, tenantId: m['tenantId'] as int, flatId: m['flatId'] as int,
    leaseStart: m['leaseStart'] as String, leaseEnd: m['leaseEnd'] as String,
    monthlyRent: (m['monthlyRent'] as num?)?.toDouble() ?? 0,
    advanceMonths: (m['advanceMonths'] as num?)?.toInt() ?? 0,
    securityDeposit: (m['securityDeposit'] as num?)?.toDouble() ?? 0,
    moveOutDate: m['moveOutDate'] as String?,
    tenantName: m['tenantName'] as String?, tenantPhone: m['tenantPhone'] as String?,
    tenantAddress: m['tenantAddress'] as String?,
    flatNumber: m['flatNumber'] as String?, buildingName: m['buildingName'] as String?,
    buildingId: m['buildingId'] as int?,
  );

  Lease copyWith({
    int? id,
    int? tenantId,
    int? flatId,
    String? leaseStart,
    String? leaseEnd,
    double? monthlyRent,
    int? advanceMonths,
    double? securityDeposit,
    String? moveOutDate,
    String? tenantName,
    String? tenantPhone,
    String? tenantAddress,
    String? flatNumber,
    String? buildingName,
    int? buildingId,
  }) => Lease(
    id: id ?? this.id,
    tenantId: tenantId ?? this.tenantId,
    flatId: flatId ?? this.flatId,
    leaseStart: leaseStart ?? this.leaseStart,
    leaseEnd: leaseEnd ?? this.leaseEnd,
    monthlyRent: monthlyRent ?? this.monthlyRent,
    advanceMonths: advanceMonths ?? this.advanceMonths,
    securityDeposit: securityDeposit ?? this.securityDeposit,
    moveOutDate: moveOutDate ?? this.moveOutDate,
    tenantName: tenantName ?? this.tenantName,
    tenantPhone: tenantPhone ?? this.tenantPhone,
    tenantAddress: tenantAddress ?? this.tenantAddress,
    flatNumber: flatNumber ?? this.flatNumber,
    buildingName: buildingName ?? this.buildingName,
    buildingId: buildingId ?? this.buildingId,
  );
}

class RentPayment {
  final int? id;
  final int leaseId;
  final int month;
  final int year;
  final double amount;
  final double amountPaid;
  final double balance;
  final String paymentDate;
  final String paymentMethod;
  final String status;
  final bool settled;
  final double discount;
  final String? tenantName;
  final String? flatNumber;
  final String? buildingName;
  final int? buildingId;
  final int? tenantId;
  final int? flatId;
  final double? monthlyRent;

  RentPayment({this.id, required this.leaseId, required this.month, required this.year, this.amount = 0, this.amountPaid = 0, this.balance = 0, required this.paymentDate, this.paymentMethod = 'Cash', this.status = 'not_paid', this.settled = false, this.discount = 0, this.tenantName, this.flatNumber, this.buildingName, this.buildingId, this.tenantId, this.flatId, this.monthlyRent});

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id, 'leaseId': leaseId, 'month': month, 'year': year,
    'amount': amount, 'amountPaid': amountPaid, 'balance': balance,
    'paymentDate': paymentDate, 'paymentMethod': paymentMethod, 'status': status,
    'settled': settled, 'discount': discount,
    if (tenantName != null) 'tenantName': tenantName,
    if (flatNumber != null) 'flatNumber': flatNumber,
    if (buildingName != null) 'buildingName': buildingName,
  };

  factory RentPayment.fromMap(Map<String, dynamic> m) => RentPayment(
    id: m['id'] as int?, leaseId: m['leaseId'] as int,
    month: m['month'] as int, year: m['year'] as int,
    amount: (m['amount'] as num?)?.toDouble() ?? 0,
    amountPaid: (m['amountPaid'] as num?)?.toDouble() ?? 0,
    balance: (m['balance'] as num?)?.toDouble() ?? 0,
    paymentDate: m['paymentDate'] as String,
    paymentMethod: (m['paymentMethod'] as String?) ?? 'Cash',
    status: (m['status'] as String?) ?? 'not_paid',
    settled: m['settled'] is bool ? m['settled'] as bool : ((m['settled'] as num?) ?? 0) > 0,
    discount: (m['discount'] as num?)?.toDouble() ?? 0,
    tenantName: m['tenantName'] as String?, flatNumber: m['flatNumber'] as String?,
    buildingName: m['buildingName'] as String?, buildingId: m['buildingId'] as int?,
    tenantId: m['tenantId'] as int?, flatId: m['flatId'] as int?,
    monthlyRent: m['monthlyRent'] != null ? (m['monthlyRent'] as num).toDouble() : null,
  );
}
