import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

const _accent = Color(0xFF6B5B95);
const _ink = Color(0xFF25242A);
const _paper = Color(0xFFF7F4EE);

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
          : _DiaryHome(user: user);
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
    required this.title,
    required this.mood,
    required this.content,
  });
  final String id, email, title, mood, content;
  final DateTime date;
  factory _DiaryEntry.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final timestamp = data['date'];
    return _DiaryEntry(
      id: doc.id,
      email: data['email'] as String? ?? '',
      date: timestamp is Timestamp ? timestamp.toDate() : DateTime.now(),
      title: data['title'] as String? ?? '',
      mood: data['mood'] as String? ?? '🙂',
      content: data['content'] as String? ?? '',
    );
  }
}

class _DiaryRepository {
  static CollectionReference<Map<String, dynamic>> entries(String uid) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('entries');

  static Stream<List<_DiaryEntry>> watch(String uid) => entries(uid)
      .orderBy('date', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map(_DiaryEntry.fromDocument).toList());

  static String newEntryId(String uid) => entries(uid).doc().id;

  static Future<void> create(
    User user, {
    required String entryId,
    required String title,
    required String mood,
    required String content,
    required DateTime date,
  }) => entries(user.uid).doc(entryId).set({
    'email': user.email ?? '',
    'date': Timestamp.fromDate(date),
    'title': title.trim(),
    'mood': mood,
    'content': content.trim(),
  });

  static Future<void> delete(String uid, String entryId) =>
      entries(uid).doc(entryId).delete();
}

class _DiaryHome extends StatefulWidget {
  const _DiaryHome({required this.user});
  final User user;

  @override
  State<_DiaryHome> createState() => _DiaryHomeState();
}

class _DiaryHomeState extends State<_DiaryHome> {
  final _searchController = TextEditingController();
  String _query = '';
  late Stream<List<_DiaryEntry>> _entriesStream;

  @override
  void initState() {
    super.initState();
    _entriesStream = _DiaryRepository.watch(widget.user.uid);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        'Daybook',
        style: TextStyle(fontWeight: FontWeight.w700),
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
                  Text('Sign out / switch account'),
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
    body: StreamBuilder<List<_DiaryEntry>>(
      stream: _entriesStream,
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return _DiaryError(error: snapshot.error.toString());
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: _accent),
                SizedBox(height: 16),
                Text('Gathering your memories…'),
              ],
            ),
          );
        final entries = snapshot.data ?? const <_DiaryEntry>[];
        if (entries.isEmpty)
          return _EmptyDiary(onCreate: () => _create(context));
        final query = _query.trim().toLowerCase();
        final filteredEntries = query.isEmpty
            ? entries
            : entries
                  .where(
                    (entry) =>
                        entry.title.toLowerCase().contains(query) ||
                        entry.content.toLowerCase().contains(query),
                  )
                  .toList();
        return ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 112),
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
              'Make room for\nyour thoughts.',
              style: TextStyle(
                color: _ink,
                fontSize: 31,
                fontWeight: FontWeight.w700,
                height: 1.12,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${entries.length} ${entries.length == 1 ? 'memory' : 'memories'} saved',
              style: const TextStyle(color: Color(0xFF85818A), fontSize: 14),
            ),
            const SizedBox(height: 22),
            TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search your entries',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Your entries',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${filteredEntries.length}',
                  style: const TextStyle(
                    color: Color(0xFF85818A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (filteredEntries.isEmpty)
              const _NoSearchResults()
            else
              ...filteredEntries.map(
                (entry) => _EntryCard(
                  entry: entry,
                  onTap: () => _openEntry(context, entry),
                ),
              ),
          ],
        );
      },
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _create(context),
      backgroundColor: _accent,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.add_rounded),
      label: const Text('New entry'),
    ),
  );

  Future<void> _create(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _EditEntryPage(user: widget.user),
      ),
    );
  }

  Future<void> _openEntry(BuildContext context, _DiaryEntry entry) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _EntryDetailPage(user: widget.user, entry: entry),
      ),
    );
  }
}

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

class _NoSearchResults extends StatelessWidget {
  const _NoSearchResults();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40),
    child: Column(
      children: [
        Icon(
          Icons.search_off_rounded,
          size: 38,
          color: _accent.withValues(alpha: .7),
        ),
        const SizedBox(height: 12),
        const Text(
          'No entries found',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        const Text(
          'Try another title or word.',
          style: TextStyle(color: Color(0xFF85818A)),
        ),
      ],
    ),
  );
}

class _EmptyDiary extends StatelessWidget {
  const _EmptyDiary({required this.onCreate});
  final VoidCallback onCreate;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.menu_book_rounded,
              size: 38,
              color: _accent,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Start with today.',
            style: TextStyle(
              color: _ink,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your first entry can be a small moment, a big feeling, or anything in between.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF77747D), height: 1.45),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('Write an entry'),
          ),
        ],
      ),
    ),
  );
}

class _EditEntryPage extends StatefulWidget {
  const _EditEntryPage({required this.user});
  final User user;
  @override
  State<_EditEntryPage> createState() => _EditEntryPageState();
}

class _EditEntryPageState extends State<_EditEntryPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _content = TextEditingController();
  DateTime _date = DateTime.now();
  String _mood = '🙂';
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
          TextFormField(
            controller: _content,
            minLines: 9,
            maxLines: null,
            maxLength: 5000,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              alignLabelWithHint: true,
              labelText: 'Your thoughts',
              hintText: 'A moment, a feeling, or anything on your mind…',
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Write a few words before saving'
                : null,
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
          Text(
            entry.content,
            style: const TextStyle(color: _ink, fontSize: 17, height: 1.65),
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
