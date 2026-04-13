// lib/screens/bookings/helper_incoming_jobs_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'incoming_booking_detail.dart';

class HelperIncomingJobsScreen extends StatefulWidget {
  const HelperIncomingJobsScreen({super.key});

  @override
  State<HelperIncomingJobsScreen> createState() =>
      _HelperIncomingJobsScreenState();
}

class _HelperIncomingJobsScreenState extends State<HelperIncomingJobsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_uid.isEmpty) {
      return const Center(child: Text('Not signed in'));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FF),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('bookings')
                  .where('helperId', isEqualTo: _uid)
                  .where('status', isEqualTo: 'booked')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, directSnap) {
                final directDocs = directSnap.data?.docs ?? [];
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('bookings')
                      .where('status', isEqualTo: 'booked')
                      .where('helperId', isNull: true)
                      .orderBy('createdAt', descending: true)
                      .limit(20)
                      .snapshots(),
                  builder: (context, openSnap) {
                    final openDocs = openSnap.data?.docs ?? [];

                    if (directSnap.connectionState ==
                        ConnectionState.waiting &&
                        !directSnap.hasData) {
                      return const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF7C3AED)));
                    }

                    if (directDocs.isEmpty && openDocs.isEmpty) {
                      return _buildEmpty();
                    }

                    return CustomScrollView(
                      physics: const ClampingScrollPhysics(),
                      slivers: [
                        if (directDocs.isNotEmpty) ...[
                          _sectionHeader('Direct Requests',
                              directDocs.length, const Color(0xFF7C3AED)),
                          SliverPadding(
                            padding:
                            const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                    (_, i) => RepaintBoundary(
                                  child: _BookingRequestCard(
                                      doc: directDocs[i]),
                                ),
                                childCount: directDocs.length,
                              ),
                            ),
                          ),
                        ],
                        if (openDocs.isNotEmpty) ...[
                          _sectionHeader('Open in Your Area',
                              openDocs.length, const Color(0xFF059669)),
                          SliverPadding(
                            padding:
                            const EdgeInsets.fromLTRB(16, 0, 16, 100),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                    (_, i) => RepaintBoundary(
                                  child: _BookingRequestCard(
                                      doc: openDocs[i]),
                                ),
                                childCount: openDocs.length,
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  SliverToBoxAdapter _sectionHeader(
      String label, int count, Color color) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Row(children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E1B4B))),
          const SizedBox(width: 8),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8)),
            child: Text('$count',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color)),
          ),
        ]),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E0640), Color(0xFF3B0764), Color(0xFF5B21B6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(children: [
              const Text('Incoming Requests',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
              const Spacer(),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('bookings')
                    .where('helperId', isEqualTo: _uid)
                    .where('status', isEqualTo: 'booked')
                    .snapshots(),
                builder: (_, snap) {
                  final count = snap.data?.docs.length ?? 0;
                  if (count == 0) return const SizedBox.shrink();
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text('$count new',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  );
                },
              ),
            ]),
          ),
          const SizedBox(height: 16),
          Container(
            height: 22,
            decoration: const BoxDecoration(
              color: Color(0xFFF8F7FF),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 72, height: 72,
          decoration: const BoxDecoration(
              color: Color(0xFFEDE9FE), shape: BoxShape.circle),
          child: const Icon(Icons.inbox_rounded,
              size: 36, color: Color(0xFF7C3AED)),
        ),
        const SizedBox(height: 16),
        const Text('No incoming requests right now',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280))),
        const SizedBox(height: 8),
        const Text('New bookings will appear here instantly',
            style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
      ]),
    );
  }
}

class _BookingRequestCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  const _BookingRequestCard({required this.doc});

  bool get _isInstant {
    final data = doc.data() as Map<String, dynamic>;
    final ts = (data['scheduledAt'] as Timestamp?)?.toDate();
    if (ts == null) return true;
    return ts.difference(DateTime.now()).inMinutes <= 120;
  }

  bool get _isPulsing {
    final data = doc.data() as Map<String, dynamic>;
    final created = (data['createdAt'] as Timestamp?)?.toDate();
    if (created == null) return false;
    return DateTime.now().difference(created).inMinutes < 10;
  }

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final serviceName = data['serviceName'] as String? ?? 'Service';
    final address = data['address'] as String? ?? '';
    final ts = (data['scheduledAt'] as Timestamp?)?.toDate()?.toLocal();
    final baseAmount = (data['baseAmount'] as num?)?.toDouble() ?? 0.0;
    final paymentMethod = data['paymentMethod'] as String? ?? 'Cash';
    final scheduled = ts != null
        ? DateFormat('d MMM, h:mm a').format(ts)
        : 'Instant';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => IncomingBookingDetail(
              bookingId: doc.id, // Firestore document ID, NOT bookingCode
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isInstant
                ? const Color(0xFF7C3AED).withOpacity(0.3)
                : const Color(0xFFEDE9FE),
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.build_rounded,
                    color: Color(0xFF7C3AED), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(serviceName,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E1B4B))),
                      const SizedBox(height: 2),
                      Row(children: [
                        const Icon(Icons.schedule_rounded,
                            size: 12, color: Color(0xFF9CA3AF)),
                        const SizedBox(width: 4),
                        Text(scheduled,
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF6B7280))),
                      ]),
                    ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('₹${baseAmount.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF7C3AED))),
                Row(children: [
                  if (_isPulsing)
                    Container(
                      width: 7, height: 7,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: const BoxDecoration(
                          color: Color(0xFF22C55E),
                          shape: BoxShape.circle),
                    ),
                  Text(paymentMethod,
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFF9CA3AF))),
                ]),
              ]),
            ]),
            if (address.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(children: [
                const Icon(Icons.location_on_rounded,
                    size: 13, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF6B7280))),
                ),
              ]),
            ],
            if (_isInstant) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFF7C3AED).withOpacity(0.25)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.flash_on_rounded,
                        size: 12, color: Color(0xFF7C3AED)),
                    SizedBox(width: 4),
                    Text('Instant Request — Respond Quickly',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF7C3AED))),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}