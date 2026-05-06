import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_provider.dart';
import '../../core/constants.dart';
import 'action_selection_screen.dart';

class EventSelectionScreen extends StatefulWidget {
  const EventSelectionScreen({super.key});

  @override
  State<EventSelectionScreen> createState() => _EventSelectionScreenState();
}

class _EventSelectionScreenState extends State<EventSelectionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EventProvider>().fetchEvents();
    });
  }

  @override
  Widget build(BuildContext context) {
    final eventProvider = context.watch<EventProvider>();
    final auth = context.read<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Event', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => auth.logout(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppConstants.primaryColor,
                  child: Text(auth.user?.name[0].toUpperCase() ?? 'U'),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello, ${auth.user?.name}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      auth.user?.tenant ?? '',
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: eventProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : eventProvider.events.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.event_busy_rounded, size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            const Text('No active events found'),
                            TextButton(
                              onPressed: () => eventProvider.fetchEvents(),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: eventProvider.events.length,
                        itemBuilder: (context, index) {
                          final event = eventProvider.events[index];
                          return FadeInUp(
                            delay: Duration(milliseconds: 100 * index),
                            child: Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () {
                                  eventProvider.selectEvent(event);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const ActionSelectionScreen()),
                                  );
                                },
                                child: Container(
                                  height: 120,
                                  decoration: BoxDecoration(
                                    image: event.backgroundImage != null
                                        ? DecorationImage(
                                            image: NetworkImage(event.backgroundImage!),
                                            fit: BoxFit.cover,
                                            colorFilter: ColorFilter.mode(
                                              Colors.black.withOpacity(0.7),
                                              BlendMode.darken,
                                            ),
                                          )
                                        : null,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                event.name,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  const Icon(Icons.location_on_outlined, size: 14, color: Colors.white70),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    event.venue,
                                                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  const Icon(Icons.calendar_today_outlined, size: 14, color: Colors.white70),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    DateFormat('dd MMM yyyy').format(event.eventStartDate),
                                                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 20),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
