import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

const _accent = Color(0xFF6B5B95);
const _ink = Color(0xFF25242A);
const _paper = Color(0xFFF7F4EE);
const _writingPrompts = [
  'What small moment made you smile today?',
  'What is something you want to remember about this week?',
  'When did you feel most like yourself today?',
  'What is one thing you are grateful for right now?',
  'What would you tell your future self about today?',
  'What felt harder than expected, and what helped?',
  'Describe a place where you felt at ease.',
];
const _paperStyles = [
  _PaperStyle(id: 'plain', label: 'Classic', color: Color(0xFFFFFEFC)),
  _PaperStyle(id: 'ruled', label: 'Ruled', color: Color(0xFFFFFEFC)),
  _PaperStyle(id: 'grid', label: 'Grid', color: Color(0xFFFDFDFF)),
  _PaperStyle(id: 'dotted', label: 'Dotted', color: Color(0xFFFFFEFC)),
  _PaperStyle(id: 'linen', label: 'Linen', color: Color(0xFFF7F0E3)),
];

class _PaperStyle {
  const _PaperStyle({
    required this.id,
    required this.label,
    required this.color,
  });
  final String id;
  final String label;
  final Color color;
}

_PaperStyle _paperStyleFor(String id) => _paperStyles.firstWhere(
  (style) => style.id == id,
  orElse: () => _paperStyles.first,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var firebaseReady = false;
  String? initError;
  try {
    await Firebase.initializeApp();
    firebaseReady = true;
  } catch (error) {
    initError = error.toString();
  }
  runApp(DiaryApp(firebaseReady: firebaseReady, initError: initError));
}

class DiaryApp extends StatelessWidget {
  const DiaryApp({super.key, required this.firebaseReady, this.initError});
  final bool firebaseReady;
  final String? initError;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Daybook',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: _paper,
      colorScheme: ColorScheme.fromSeed(seedColor: _accent),
      appBarTheme: const AppBarTheme(
        backgroundColor: _paper,
        foregroundColor: _ink,
        elevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    ),
    home: firebaseReady
        ? const _AuthGate()
        : _LoginPage(firebaseReady: false, setupError: initError),
  );
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();
  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: FirebaseAuth.instance.authStateChanges(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator(color: _accent)),
        );
      }
      final user = snapshot.data;
      return user == null
          ? const _LoginPage(firebaseReady: true)
          : _DiaryShell(user: user);
    },
  );
}

class _LoginPage extends StatefulWidget {
  const _LoginPage({required this.firebaseReady, this.setupError});
  final bool firebaseReady;
  final String? setupError;
  @override
  State<_LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<_LoginPage> with WidgetsBindingObserver {
  bool _busy = false;
  String? _error;
  int _nextAttempt = 0;
  int? _activeAttempt;
  bool _leftAppForSignIn = false;
  Timer? _resumeTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _resumeTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ((state == AppLifecycleState.inactive ||
            state == AppLifecycleState.paused) &&
        _busy) {
      _leftAppForSignIn = true;
      return;
    }

    if (state != AppLifecycleState.resumed || !_busy || !_leftAppForSignIn) {
      return;
    }

    _leftAppForSignIn = false;
    final attempt = _activeAttempt;
    if (attempt == null) return;
    _resumeTimer?.cancel();
    _resumeTimer = Timer(const Duration(seconds: 10), () {
      if (!mounted ||
          _activeAttempt != attempt ||
          FirebaseAuth.instance.currentUser != null) {
        return;
      }
      setState(() {
        _activeAttempt = null;
        _busy = false;
        _error = 'Sign-in was canceled. Please try again.';
      });
    });
  }

  Future<void> _signIn(bool useGoogle) async {
    final attempt = ++_nextAttempt;
    _activeAttempt = attempt;
    _resumeTimer?.cancel();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final AuthProvider provider = useGoogle
          ? (GoogleAuthProvider()
              ..setCustomParameters({'prompt': 'select_account'}))
          : (GithubAuthProvider()
              ..addScope('user:email')
              ..setCustomParameters({'prompt': 'select_account'}));
      await FirebaseAuth.instance
          .signInWithProvider(provider)
          .timeout(const Duration(minutes: 2));
    } on FirebaseAuthException catch (error) {
      if (!useGoogle &&
          error.code == 'account-exists-with-different-credential') {
        try {
          final pendingCredential = error.credential;
          final email = error.email?.trim().toLowerCase();
          if (pendingCredential == null || email == null || email.isEmpty) {
            throw StateError(
              'This email already has a Daybook account. Sign in with Google first, then try GitHub again.',
            );
          }

          final googleResult = await FirebaseAuth.instance
              .signInWithProvider(GoogleAuthProvider())
              .timeout(const Duration(minutes: 2));
          final googleUser = googleResult.user;
          if (googleUser == null ||
              googleUser.email?.trim().toLowerCase() != email) {
            await FirebaseAuth.instance.signOut();
            throw StateError(
              'Please choose the same Google account that uses $email, then try GitHub again.',
            );
          }

          await googleUser.linkWithCredential(pendingCredential);
        } catch (linkError) {
          if (mounted && _activeAttempt == attempt) {
            setState(() {
              _error = linkError is FirebaseAuthException
                  ? linkError.message ??
                        'Could not link GitHub to this account.'
                  : linkError.toString().replaceFirst('Bad state: ', '');
            });
          }
        }
      } else if (mounted && _activeAttempt == attempt) {
        setState(
          () => _error = error.message ?? 'Sign-in failed. Please try again.',
        );
      }
    } on TimeoutException {
      if (mounted && _activeAttempt == attempt) {
        setState(() => _error = 'Sign-in timed out. Please try again.');
      }
    } catch (error) {
      if (mounted && _activeAttempt == attempt) {
        setState(() => _error = 'Sign-in failed: $error');
      }
    } finally {
      if (mounted && _activeAttempt == attempt) {
        _resumeTimer?.cancel();
        setState(() {
          _activeAttempt = null;
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.auto_stories_rounded,
                    size: 32,
                    color: _accent,
                  ),
                ),
                const SizedBox(height: 34),
                const Text(
                  'A little space\nfor every day.',
                  style: TextStyle(
                    fontSize: 38,
                    height: 1.12,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Keep your thoughts, moments, and moods in one private place.',
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: Color(0xFF77747D),
                  ),
                ),
                const SizedBox(height: 34),
                _ProviderButton(
                  label: 'Continue with Google',
                  icon: Icons.g_mobiledata_rounded,
                  enabled: widget.firebaseReady && !_busy,
                  onTap: () => _signIn(true),
                ),
                const SizedBox(height: 12),
                _ProviderButton(
                  label: 'Continue with GitHub',
                  icon: Icons.code_rounded,
                  enabled: widget.firebaseReady && !_busy,
                  onTap: () => _signIn(false),
                  dark: true,
                ),
                if (_busy) ...[
                  const SizedBox(height: 18),
                  const Center(
                    child: CircularProgressIndicator(color: _accent),
                  ),
                ],
                if (_error != null) _MessageCard(text: _error!, isError: true),
                if (!widget.firebaseReady) ...[
                  const SizedBox(height: 24),
                  _MessageCard(
                    isError: false,
                    text: widget.setupError == null
                        ? 'Firebase is not configured yet. Add the platform config file from README.md to enable Google and GitHub sign-in.'
                        : 'Firebase could not start. Check the project configuration in README.md.\n${widget.setupError}',
                  ),
                ],
                const SizedBox(height: 30),
                const Center(
                  child: Text(
                    'Your diary is private to your account.',
                    style: TextStyle(color: Color(0xFF89858D), fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _ProviderButton extends StatelessWidget {
  const _ProviderButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onTap,
    this.dark = false,
  });
  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final bool dark;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 54,
    child: FilledButton.tonalIcon(
      onPressed: enabled ? onTap : null,
      style: FilledButton.styleFrom(
        backgroundColor: dark ? const Color(0xFF27262B) : Colors.white,
        foregroundColor: dark ? Colors.white : _ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      icon: Icon(icon, size: 24),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    ),
  );
}

class _DiaryEntry {
  const _DiaryEntry({
    required this.id,
    required this.email,
    required this.date,
    required this.createdAt,
    required this.title,
    required this.mood,
    required this.content,
    required this.paperStyle,
  });
  final String id, email, title, mood, content, paperStyle;
  final DateTime date, createdAt;
  factory _DiaryEntry.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final timestamp = data['date'];
    final date = timestamp is Timestamp ? timestamp.toDate() : DateTime.now();
    final createdAtValue = data['createdAt'];
    return _DiaryEntry(
      id: doc.id,
      email: data['email'] as String? ?? '',
      date: date,
      createdAt: createdAtValue is Timestamp ? createdAtValue.toDate() : date,
      title: data['title'] as String? ?? '',
      mood: data['mood'] as String? ?? '🙂',
      content: data['content'] as String? ?? '',
      paperStyle: data['paperStyle'] as String? ?? 'plain',
    );
  }
}

class _DiaryRepository {
  static CollectionReference<Map<String, dynamic>> entries(String uid) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('entries');

  static Stream<List<_DiaryEntry>> watch(String uid) =>
      entries(uid).snapshots().map((snapshot) {
        final result = snapshot.docs.map(_DiaryEntry.fromDocument).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return result;
      });

  static String newEntryId(String uid) => entries(uid).doc().id;

  static Future<void> create(
    User user, {
    required String entryId,
    required String title,
    required String mood,
    required String content,
    required String paperStyle,
    required DateTime date,
  }) => entries(user.uid).doc(entryId).set({
    'email': user.email ?? '',
    'date': Timestamp.fromDate(date),
    'createdAt': Timestamp.now(),
    'title': title.trim(),
    'mood': mood,
    'content': content.trim(),
    'paperStyle': paperStyle,
  });

  static Future<void> delete(String uid, String entryId) =>
      entries(uid).doc(entryId).delete();
}

class _DiaryShell extends StatefulWidget {
  const _DiaryShell({required this.user});
  final User user;

  @override
  State<_DiaryShell> createState() => _DiaryShellState();
}

class _DiaryShellState extends State<_DiaryShell> {
  int _selectedIndex = 0;

  Future<void> _createEntry({String? prompt}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _EditEntryPage(user: widget.user, prompt: prompt),
      ),
    );
  }

  Future<void> _openEntry(_DiaryEntry entry) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _EntryDetailPage(user: widget.user, entry: entry),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        _selectedIndex == 0 ? 'Profile' : 'Agenda',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      actions: [
        PopupMenuButton<String>(
          tooltip: 'Account options',
          onSelected: (value) async {
            if (value == 'sign_out') await FirebaseAuth.instance.signOut();
          },
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              enabled: false,
              child: Text(widget.user.email ?? 'Signed in'),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem<String>(
              value: 'sign_out',
              child: Row(
                children: [
                  Icon(Icons.logout_rounded, size: 20),
                  SizedBox(width: 10),
                  Text('Sign out'),
                ],
              ),
            ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: CircleAvatar(
              backgroundColor: _accent.withValues(alpha: .14),
              child: Text(
                _userInitial(widget.user),
                style: const TextStyle(
                  color: _accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
    body: IndexedStack(
      index: _selectedIndex,
      children: [
        _ProfilePage(
          user: widget.user,
          onCreateEntry: () => _createEntry(),
          onUsePrompt: (prompt) => _createEntry(prompt: prompt),
          onOpenEntry: _openEntry,
        ),
        _AgendaPage(user: widget.user, onOpenEntry: _openEntry),
      ],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (index) => setState(() => _selectedIndex = index),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: 'Profile',
        ),
        NavigationDestination(
          icon: Icon(Icons.calendar_month_outlined),
          selectedIcon: Icon(Icons.calendar_month_rounded),
          label: 'Agenda',
        ),
      ],
    ),
  );
}

class _ProfilePage extends StatefulWidget {
  const _ProfilePage({
    required this.user,
    required this.onCreateEntry,
    required this.onUsePrompt,
    required this.onOpenEntry,
  });
  final User user;
  final VoidCallback onCreateEntry;
  final ValueChanged<String> onUsePrompt;
  final ValueChanged<_DiaryEntry> onOpenEntry;

  @override
  State<_ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<_ProfilePage> {
  late Stream<List<_DiaryEntry>> _entriesStream;
  late int _promptIndex;

  @override
  void initState() {
    super.initState();
    _entriesStream = _DiaryRepository.watch(widget.user.uid);
    _promptIndex = DateTime.now().day % _writingPrompts.length;
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<_DiaryEntry>>(
    stream: _entriesStream,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _DiaryError(error: snapshot.error.toString());
      }
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const _PageLoading(label: 'Loading your profile…');
      }

      final entries = snapshot.data ?? const <_DiaryEntry>[];
      final moodCounts = <String, int>{};
      for (final entry in entries) {
        moodCounts.update(
          entry.mood,
          (previousCount) => previousCount + 1,
          ifAbsent: () => 1,
        );
      }
      final moods = moodCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
        children: [
          Text(
            '${_timeGreeting()}, ${_greetingName(widget.user)}',
            style: const TextStyle(
              color: Color(0xFF77747D),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Your story,\none day at a time.',
            style: TextStyle(
              color: _ink,
              fontSize: 30,
              fontWeight: FontWeight.w700,
              height: 1.12,
            ),
          ),
          const SizedBox(height: 20),
          _TotalEntriesCard(count: entries.length),
          const SizedBox(height: 14),
          _WeeklyMoodStrip(entries: entries),
          const SizedBox(height: 14),
          _WritingPromptCard(
            prompt: _writingPrompts[_promptIndex],
            onShuffle: () => setState(
              () => _promptIndex = (_promptIndex + 1) % _writingPrompts.length,
            ),
            onWrite: () => widget.onUsePrompt(_writingPrompts[_promptIndex]),
          ),
          const SizedBox(height: 26),
          _SectionHeading(title: 'Recent entries', trailing: 'Last 2'),
          const SizedBox(height: 10),
          if (entries.isEmpty)
            const _InlineEmptyState(
              icon: Icons.menu_book_rounded,
              title: 'Your journal starts here',
              message: 'Add a first entry whenever you are ready.',
            )
          else
            ...entries
                .take(2)
                .map(
                  (entry) => _EntryCard(
                    entry: entry,
                    onTap: () => widget.onOpenEntry(entry),
                  ),
                ),
          const SizedBox(height: 14),
          _SectionHeading(title: 'Feelings', trailing: 'All entries'),
          const SizedBox(height: 10),
          if (moods.isEmpty)
            const _InlineEmptyState(
              icon: Icons.mood_rounded,
              title: 'Your mood patterns will appear here',
              message: 'Choose a feeling when you write an entry.',
            )
          else
            Card(
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    for (var index = 0; index < moods.length; index++)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: index == moods.length - 1 ? 0 : 14,
                        ),
                        child: _MoodShareRow(
                          mood: moods[index].key,
                          count: moods[index].value,
                          total: entries.length,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: widget.onCreateEntry,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Write a new entry'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _AgendaPage extends StatefulWidget {
  const _AgendaPage({required this.user, required this.onOpenEntry});
  final User user;
  final ValueChanged<_DiaryEntry> onOpenEntry;

  @override
  State<_AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends State<_AgendaPage> {
  late Stream<List<_DiaryEntry>> _entriesStream;
  late DateTime _focusedDay;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    _entriesStream = _DiaryRepository.watch(widget.user.uid);
    _focusedDay = DateTime.now();
    _selectedDay = DateTime.now();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<_DiaryEntry>>(
    stream: _entriesStream,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _DiaryError(error: snapshot.error.toString());
      }
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const _PageLoading(label: 'Loading your agenda…');
      }

      final entries = snapshot.data ?? const <_DiaryEntry>[];
      final selectedEntries = entries
          .where((entry) => _sameDay(entry.date, _selectedDay))
          .toList();

      return Column(
        children: [
          Card(
            color: Colors.white,
            elevation: 0,
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
              child: TableCalendar<_DiaryEntry>(
                firstDay: DateTime.utc(2000, 1, 1),
                lastDay: DateTime.utc(2100, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => _sameDay(day, _selectedDay),
                eventLoader: (day) => entries
                    .where((entry) => _sameDay(entry.date, day))
                    .toList(),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                onPageChanged: (focusedDay) {
                  _focusedDay = focusedDay;
                },
                headerStyle: const HeaderStyle(
                  titleCentered: true,
                  formatButtonVisible: false,
                  leftChevronIcon: Icon(Icons.chevron_left_rounded),
                  rightChevronIcon: Icon(Icons.chevron_right_rounded),
                ),
                calendarStyle: CalendarStyle(
                  outsideDaysVisible: false,
                  markersMaxCount: 3,
                  markerDecoration: const BoxDecoration(
                    color: _accent,
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    color: _accent.withValues(alpha: .18),
                    shape: BoxShape.circle,
                  ),
                  todayTextStyle: const TextStyle(
                    color: _accent,
                    fontWeight: FontWeight.w700,
                  ),
                  selectedDecoration: const BoxDecoration(
                    color: _accent,
                    shape: BoxShape.circle,
                  ),
                  selectedTextStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: _SectionHeading(
              title: _isToday(_selectedDay)
                  ? 'Today'
                  : _dateLabel(_selectedDay),
              trailing:
                  '${selectedEntries.length} ${selectedEntries.length == 1 ? 'entry' : 'entries'}',
            ),
          ),
          Expanded(
            child: selectedEntries.isEmpty
                ? const _InlineEmptyState(
                    icon: Icons.event_note_rounded,
                    title: 'Nothing written this day',
                    message: 'Choose another date to revisit your entries.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: selectedEntries.length,
                    itemBuilder: (context, index) => _EntryCard(
                      entry: selectedEntries[index],
                      onTap: () => widget.onOpenEntry(selectedEntries[index]),
                    ),
                  ),
          ),
        ],
      );
    },
  );
}

class _TotalEntriesCard extends StatelessWidget {
  const _TotalEntriesCard({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: _accent,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your journal',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              SizedBox(height: 5),
              Text(
                'Every day counts.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Text(
          '$count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 38,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _WeeklyMoodStrip extends StatelessWidget {
  const _WeeklyMoodStrip({required this.entries});
  final List<_DiaryEntry> entries;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final days = List.generate(
      7,
      (index) => DateTime(today.year, today.month, today.day - 6 + index),
    );
    final activeDays = days
        .where((day) => entries.any((entry) => _sameDay(entry.date, day)))
        .length;

    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Your week',
                    style: TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                Text(
                  '$activeDays active ${activeDays == 1 ? 'day' : 'days'}',
                  style: const TextStyle(
                    color: Color(0xFF85818A),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                for (final day in days)
                  Expanded(
                    child: _WeekMoodDay(
                      day: day,
                      mood: _moodForDay(entries, day),
                      isToday: _sameDay(day, today),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String? _moodForDay(List<_DiaryEntry> entries, DateTime day) {
    for (final entry in entries) {
      if (_sameDay(entry.date, day)) return entry.mood;
    }
    return null;
  }
}

class _WeekMoodDay extends StatelessWidget {
  const _WeekMoodDay({
    required this.day,
    required this.mood,
    required this.isToday,
  });
  final DateTime day;
  final String? mood;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    const weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Column(
      children: [
        CircleAvatar(
          radius: 19,
          backgroundColor: isToday
              ? _accent.withValues(alpha: .14)
              : const Color(0xFFF6F3F8),
          child: mood == null
              ? Icon(
                  Icons.remove_rounded,
                  size: 17,
                  color: isToday ? _accent : const Color(0xFFB8B3BE),
                )
              : Text(mood!, style: const TextStyle(fontSize: 18)),
        ),
        const SizedBox(height: 6),
        Text(
          weekdays[day.weekday - 1],
          style: TextStyle(
            color: isToday ? _accent : const Color(0xFF85818A),
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _WritingPromptCard extends StatelessWidget {
  const _WritingPromptCard({
    required this.prompt,
    required this.onShuffle,
    required this.onWrite,
  });
  final String prompt;
  final VoidCallback onShuffle;
  final VoidCallback onWrite;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(18, 16, 12, 14),
    decoration: BoxDecoration(
      color: const Color(0xFFECE8F4),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome_rounded, color: _accent, size: 19),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'A little writing spark',
                style: TextStyle(
                  color: _accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            IconButton(
              onPressed: onShuffle,
              tooltip: 'Another prompt',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.refresh_rounded, color: _accent),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 27, right: 8),
          child: Text(
            prompt,
            style: const TextStyle(
              color: _ink,
              fontSize: 16,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onWrite,
            icon: const Icon(Icons.edit_rounded, size: 17),
            label: const Text('Write about it'),
            style: TextButton.styleFrom(foregroundColor: _accent),
          ),
        ),
      ],
    ),
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.trailing});
  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            color: _ink,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      Text(
        trailing,
        style: const TextStyle(
          color: Color(0xFF85818A),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );
}

class _MoodShareRow extends StatelessWidget {
  const _MoodShareRow({
    required this.mood,
    required this.count,
    required this.total,
  });
  final String mood;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final percentage = count / total;
    return Row(
      children: [
        Text(mood, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percentage,
              minHeight: 8,
              backgroundColor: const Color(0xFFECEAF0),
              color: _accent,
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 42,
          child: Text(
            '${(percentage * 100).round()}%',
            textAlign: TextAlign.end,
            style: const TextStyle(color: _ink, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _InlineEmptyState extends StatelessWidget {
  const _InlineEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: _accent, size: 30),
        const SizedBox(height: 8),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _ink, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF85818A),
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ],
    ),
  );
}

class _PageLoading extends StatelessWidget {
  const _PageLoading({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(color: _accent),
        const SizedBox(height: 14),
        Text(label, style: const TextStyle(color: Color(0xFF77747D))),
      ],
    ),
  );
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool _isToday(DateTime date) => _sameDay(date, DateTime.now());

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry, required this.onTap});
  final _DiaryEntry entry;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    color: Colors.white,
    elevation: 0,
    margin: const EdgeInsets.only(bottom: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 23,
              backgroundColor: _accent.withValues(alpha: .10),
              child: Text(entry.mood, style: const TextStyle(fontSize: 21)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _dateLabel(entry.date),
                    style: const TextStyle(
                      color: Color(0xFF85818A),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (entry.content.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      entry.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF77747D),
                        height: 1.35,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF8A8492)),
          ],
        ),
      ),
    ),
  );
}

class _PaperStylePicker extends StatelessWidget {
  const _PaperStylePicker({required this.selectedId, required this.onSelected});
  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final style in _paperStyles)
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: _PaperStyleOption(
              style: style,
              selected: style.id == selectedId,
              onTap: () => onSelected(style.id),
            ),
          ),
      ],
    ),
  );
}

class _PaperStyleOption extends StatelessWidget {
  const _PaperStyleOption({
    required this.style,
    required this.selected,
    required this.onTap,
  });
  final _PaperStyle style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: '${style.label} paper',
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 92,
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: selected ? _accent : const Color(0xFFE8E4EC),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            SizedBox(
              height: 44,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CustomPaint(
                  painter: _PaperPatternPainter(style),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              style.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? _accent : const Color(0xFF77747D),
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PaperPatternPainter extends CustomPainter {
  const _PaperPatternPainter(this.style);
  final _PaperStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(style.color, BlendMode.srcOver);
    final linePaint = Paint()
      ..color = const Color(0xFF9C8DB8).withValues(alpha: .22)
      ..strokeWidth = 1;

    switch (style.id) {
      case 'ruled':
        for (var y = 25.0; y < size.height; y += 24) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
        }
        final marginPaint = Paint()
          ..color = const Color(0xFFD98B8B).withValues(alpha: .45)
          ..strokeWidth = 1;
        canvas.drawLine(
          const Offset(22, 0),
          Offset(22, size.height),
          marginPaint,
        );
      case 'grid':
        for (var x = 16.0; x < size.width; x += 18) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
        }
        for (var y = 16.0; y < size.height; y += 18) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
        }
      case 'dotted':
        final dotPaint = Paint()
          ..color = const Color(0xFF8C7CAB).withValues(alpha: .42);
        for (var x = 12.0; x < size.width; x += 16) {
          for (var y = 12.0; y < size.height; y += 16) {
            canvas.drawCircle(Offset(x, y), 1.1, dotPaint);
          }
        }
      case 'linen':
        final grainPaint = Paint()
          ..color = const Color(0xFFAD9877).withValues(alpha: .16)
          ..strokeWidth = .7;
        for (var y = 8.0; y < size.height; y += 12) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), grainPaint);
        }
      default:
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _PaperPatternPainter oldDelegate) =>
      oldDelegate.style.id != style.id;
}

class _EditEntryPage extends StatefulWidget {
  const _EditEntryPage({required this.user, this.prompt});
  final User user;
  final String? prompt;
  @override
  State<_EditEntryPage> createState() => _EditEntryPageState();
}

class _EditEntryPageState extends State<_EditEntryPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _content = TextEditingController();
  DateTime _date = DateTime.now();
  String _mood = '🙂';
  String _paperStyle = 'plain';
  bool _saving = false;
  String? _pendingEntryId;
  static const _moods = ['😊', '😌', '🥰', '😐', '😔', '😤', '😴'];

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _DiaryRepository.create(
        widget.user,
        entryId: _pendingEntryId ??= _DiaryRepository.newEntryId(
          widget.user.uid,
        ),
        title: _title.text,
        mood: _mood,
        content: _content.text,
        paperStyle: _paperStyle,
        date: _date,
      ).timeout(const Duration(seconds: 20));
      if (mounted) Navigator.of(context).pop();
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Save timed out. Check that Cloud Firestore is created and its rules allow your signed-in account. You can retry safely.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save entry: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('New entry'),
      actions: [
        TextButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
        const SizedBox(width: 8),
      ],
    ),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          TextButton.icon(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2000),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) setState(() => _date = picked);
            },
            icon: const Icon(Icons.calendar_month_rounded),
            label: Text(_dateLabel(_date)),
          ),
          const SizedBox(height: 14),
          if (widget.prompt != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFECE8F4),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.auto_awesome_rounded, color: _accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.prompt!,
                      style: const TextStyle(color: _ink, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          TextFormField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            maxLength: 80,
            decoration: const InputDecoration(
              labelText: 'Title',
              hintText: 'Give this memory a name',
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Add a title for this entry'
                : null,
          ),
          const SizedBox(height: 22),
          const Text(
            'How are you feeling?',
            style: TextStyle(color: _ink, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 9,
            runSpacing: 8,
            children: [
              for (final mood in _moods)
                ChoiceChip(
                  label: Text(mood, style: const TextStyle(fontSize: 21)),
                  selected: _mood == mood,
                  onSelected: (_) => setState(() => _mood = mood),
                ),
            ],
          ),
          const SizedBox(height: 22),
          const Text(
            'Choose your paper',
            style: TextStyle(color: _ink, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            'Pick a page that feels right for today.',
            style: TextStyle(color: Color(0xFF85818A), fontSize: 13),
          ),
          const SizedBox(height: 10),
          _PaperStylePicker(
            selectedId: _paperStyle,
            onSelected: (style) => setState(() => _paperStyle = style),
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: CustomPaint(
              painter: _PaperPatternPainter(_paperStyleFor(_paperStyle)),
              child: TextFormField(
                controller: _content,
                minLines: 9,
                maxLines: null,
                maxLength: 5000,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(color: _ink, fontSize: 16, height: 1.65),
                decoration: InputDecoration(
                  filled: false,
                  alignLabelWithHint: true,
                  labelText: 'Your thoughts',
                  hintText: widget.prompt == null
                      ? 'A moment, a feeling, or anything on your mind…'
                      : 'Start wherever you like…',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.all(18),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Write a few words before saving'
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_rounded),
            label: Text(_saving ? 'Saving your entry…' : 'Save entry'),
          ),
        ],
      ),
    ),
  );
}

class _EntryDetailPage extends StatelessWidget {
  const _EntryDetailPage({required this.user, required this.entry});
  final User user;
  final _DiaryEntry entry;
  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this entry?'),
        content: const Text('This entry will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _DiaryRepository.delete(user.uid, entry.id);
      if (context.mounted) Navigator.of(context).pop();
    } catch (error) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete entry: $error')),
        );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Entry'),
      actions: [
        IconButton(
          tooltip: 'Delete entry',
          onPressed: () => _delete(context),
          icon: const Icon(Icons.delete_outline_rounded),
        ),
        const SizedBox(width: 6),
      ],
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _dateLabel(entry.date),
            style: const TextStyle(color: Color(0xFF77747D)),
          ),
          const SizedBox(height: 10),
          Text(
            entry.title,
            style: const TextStyle(
              color: _ink,
              fontSize: 30,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Text(entry.mood, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              const Text(
                'Mood of the day',
                style: TextStyle(color: Color(0xFF77747D)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: CustomPaint(
                painter: _PaperPatternPainter(_paperStyleFor(entry.paperStyle)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    entry.content,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 17,
                      height: 1.75,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _DiaryError extends StatelessWidget {
  const _DiaryError({required this.error});
  final String error;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        'Could not load your entries. Check your Firestore setup and security rules.\n\n$error',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xFF77747D), height: 1.5),
      ),
    ),
  );
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.text, required this.isError});
  final String text;
  final bool isError;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 18),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: isError ? const Color(0xFFFFE8E6) : const Color(0xFFECE8F4),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: isError ? const Color(0xFF9B2C2C) : const Color(0xFF51456F),
        height: 1.4,
        fontSize: 13,
      ),
    ),
  );
}

String _dateLabel(DateTime date) {
  const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}, ${date.year}';
}

String _timeGreeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning';
  if (hour < 18) return 'Good afternoon';
  return 'Good evening';
}

String _userInitial(User user) {
  final displayName = user.displayName?.trim() ?? '';
  if (displayName.isNotEmpty) return displayName.characters.first.toUpperCase();

  final email = user.email?.trim() ?? '';
  if (email.isNotEmpty) return email.characters.first.toUpperCase();
  return 'D';
}

String _greetingName(User user) {
  final displayName = user.displayName?.trim() ?? '';
  if (displayName.isNotEmpty) return displayName.split(RegExp(r'\s+')).first;
  final emailName = user.email?.split('@').first ?? '';
  if (emailName.isEmpty ||
      emailName.length > 20 ||
      RegExp(r'^\d+$').hasMatch(emailName)) {
    return 'there';
  }
  return emailName.replaceAll(RegExp(r'[._-]+'), ' ');
}
