import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fest_app/collections/event.dart';
import 'package:fest_app/data.dart';
import 'package:fest_app/pages/Homepages/ExploreEvents/widgets/sectionTitle.dart';
import 'package:fest_app/pages/Fests/festTemplatePage.dart';
import 'package:fest_app/pages/Homepages/ExploreEvents/widgets/addEventDialog.dart';

class ExploreEvents extends StatefulWidget {
  const ExploreEvents({super.key});

  @override
  _ExploreEventsState createState() => _ExploreEventsState();
}

class _ExploreEventsState extends State<ExploreEvents> {
  final _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UserData _userData = UserData();
  late Future<DocumentSnapshot> _user;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }
  
  void _loadUser() async {
    _user = _userData.getUser(); // Get cached user data
    setState(() {}); // Refresh UI
  }

  Stream<Map<String, List<Event>>> _fetchEvents() {
    return _firestore.collection('fests').snapshots().map((snapshot) {
      List<Event> pastEvents = [];
      List<Event> ongoingEvents = [];
      List<Event> upcomingEvents = [];

      DateTime now = DateTime.now();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        DateTime startDate = (data['startDate'] as Timestamp).toDate();
        DateTime endDate = (data['endDate'] as Timestamp).toDate();

        Event event = Event(
          name: data['title'] ?? 'Unnamed Event',
          date:
              "${startDate.toLocal().toString().split(' ')[0]} - ${endDate.toLocal().toString().split(' ')[0]}",
          colors: [
            Colors.blueAccent.withOpacity(0.9),
            Colors.deepPurple.withOpacity(0.7)
          ],
          navigateTo: TemplatePage(
            title: data['title'] ?? 'Unnamed Event',
            docId: doc.id,
          ),
        );

        if (endDate.isBefore(now)) {
          pastEvents.add(event);
        } else if (startDate.isBefore(now) && endDate.isAfter(now)) {
          ongoingEvents.add(event);
        } else {
          upcomingEvents.add(event);
        }
      }

      return {
        "Past Events": pastEvents,
        "Ongoing Events": ongoingEvents,
        "Upcoming Events": upcomingEvents,
      };
    });
  }

  /// Builds a card widget for the given event.
  Widget _buildEventCard(Event event) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        elevation: 4,
        child: InkWell(
          borderRadius: BorderRadius.circular(12.0),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => event.navigateTo),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12.0),
              gradient: LinearGradient(
                colors: event.colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  event.date,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds a list view of event cards.
  Widget _buildEventList(List<Event> events) {
    return ListView.builder(
      itemCount: events.length,
      itemBuilder: (context, index) => _buildEventCard(events[index]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: _user,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasData && snapshot.data!.exists) {
          final userData = snapshot.data!.data() as Map<String, dynamic>;
          _isAdmin = userData['admin'] ?? false;
        }

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: const Text(
                "Events",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
              backgroundColor: const Color.fromARGB(255, 84, 91, 216),
              actions: [
                if (_isAdmin)
                  IconButton(
                    icon: const Icon(Icons.add, color: Colors.white),
                    onPressed: () => showAddEventDialog(context),
                  ),
              ],
              bottom: const TabBar(
                tabs: [
                  Tab(
                    child: Text(
                      "Ongoing",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Tab(
                    child: Text(
                      "Upcoming",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Tab(
                    child: Text(
                      "Past",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            backgroundColor: Colors.grey[200],
            body: Padding(
              padding: const EdgeInsets.all(16.0),
              child: StreamBuilder<Map<String, List<Event>>>(
                stream: _fetchEvents(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text("No events available."));
                  }

                  final eventsMap = snapshot.data!;
                  return TabBarView(
                    children: [
                      // Ongoing Events Tab
                      eventsMap["Ongoing Events"]!.isNotEmpty
                          ? _buildEventList(eventsMap["Ongoing Events"]!)
                          : const Center(child: Text("No Ongoing Events available.")),
                      // Upcoming Events Tab
                      eventsMap["Upcoming Events"]!.isNotEmpty
                          ? _buildEventList(eventsMap["Upcoming Events"]!)
                          : const Center(child: Text("No Upcoming Events available.")),
                      // Past Events Tab
                      eventsMap["Past Events"]!.isNotEmpty
                          ? _buildEventList(eventsMap["Past Events"]!)
                          : const Center(child: Text("No Past Events available.")),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
