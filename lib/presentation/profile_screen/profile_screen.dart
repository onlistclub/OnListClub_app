import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_export.dart';
import '../../core/services/orders_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/utils/analytics_mixin.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/custom_top_bar.dart';
import '../../widgets/shared_footer.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  static Widget builder(BuildContext context) => const ProfileScreen();

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with ScreenAnalytics {
  @override
  String get screenName => 'profile';

  final _nomeCtrl = TextEditingController();
  final _cognomeCtrl = TextEditingController();
  final _dataNascitaCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasChanges = false;
  List<Map<String, dynamic>> _preferiti = [];

  // Valori originali per confronto
  String _origNome = '';
  String _origCognome = '';
  String _origDob = '';

  @override
  void initState() {
    super.initState();
    _loadData();
    _nomeCtrl.addListener(_checkChanges);
    _cognomeCtrl.addListener(_checkChanges);
    _dataNascitaCtrl.addListener(_checkChanges);
  }

  @override
  void dispose() {
    _nomeCtrl.removeListener(_checkChanges);
    _cognomeCtrl.removeListener(_checkChanges);
    _dataNascitaCtrl.removeListener(_checkChanges);
    _nomeCtrl.dispose();
    _cognomeCtrl.dispose();
    _dataNascitaCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  void _checkChanges() {
    final changed = _nomeCtrl.text != _origNome ||
        _cognomeCtrl.text != _origCognome ||
        _dataNascitaCtrl.text != _origDob;
    if (changed != _hasChanges) setState(() => _hasChanges = changed);
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        OrdersService.getUserProfile(),
        OrdersService.getPreferiti(),
      ]);

      final profile = results[0] as Map<String, dynamic>?;
      final preferiti = results[1] as List<Map<String, dynamic>>;

      if (profile != null) {
        _nomeCtrl.text = profile['nome'] ?? '';
        _cognomeCtrl.text = profile['cognome'] ?? '';
        _emailCtrl.text = profile['email'] ?? Supabase.instance.client.auth.currentUser?.email ?? '';
        final dob = profile['data_nascita'];
        if (dob != null) {
          try {
            final date = DateTime.parse(dob.toString());
            _dataNascitaCtrl.text = DateFormat('dd/MM/yyyy').format(date);
          } catch (_) {
            _dataNascitaCtrl.text = dob.toString();
          }
        }
      }

      // Salva valori originali
      _origNome = _nomeCtrl.text;
      _origCognome = _cognomeCtrl.text;
      _origDob = _dataNascitaCtrl.text;

      setState(() {
        _preferiti = preferiti;
        _isLoading = false;
        _hasChanges = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('[ProfileScreen] Errore caricamento: $e');
    }
  }

  Future<void> _pickDate() async {
    DateTime initial = DateTime(2000, 1, 1);
    if (_dataNascitaCtrl.text.isNotEmpty) {
      try {
        initial = DateFormat('dd/MM/yyyy').parse(_dataNascitaCtrl.text);
      } catch (_) {}
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      locale: const Locale('it', 'IT'),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF1D00FF),
              onPrimary: Colors.white,
              surface: Color(0xFF1A1A1A),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF1A1A1A),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      _dataNascitaCtrl.text = DateFormat('dd/MM/yyyy').format(picked);
    }
  }

  Future<void> _saveProfile() async {
    if (!_hasChanges) return;
    setState(() => _isSaving = true);
    try {
      String? dataNascitaDb;
      if (_dataNascitaCtrl.text.isNotEmpty) {
        try {
          final date = DateFormat('dd/MM/yyyy').parse(_dataNascitaCtrl.text);
          dataNascitaDb = DateFormat('yyyy-MM-dd').format(date);
        } catch (_) {
          dataNascitaDb = _dataNascitaCtrl.text;
        }
      }

      await OrdersService.updateProfile(
        nome: _nomeCtrl.text.isEmpty ? null : _nomeCtrl.text,
        cognome: _cognomeCtrl.text.isEmpty ? null : _cognomeCtrl.text,
        dataNascita: dataNascitaDb,
      );

      // Aggiorna valori originali
      _origNome = _nomeCtrl.text;
      _origCognome = _cognomeCtrl.text;
      _origDob = _dataNascitaCtrl.text;

      if (mounted) {
        setState(() => _hasChanges = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text('Profilo aggiornato!', style: GoogleFonts.inter(color: Colors.white)),
              ],
            ),
            backgroundColor: const Color(0xFF1D00FF),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: $e', style: GoogleFonts.inter(color: Colors.white)),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _changePassword() async {
    final email = _emailCtrl.text;
    if (email.isEmpty) return;

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      await NotificationService.sendPasswordChangeNotification();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.email_outlined, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text('Email di reset inviata a $email', style: GoogleFonts.inter(color: Colors.white))),
              ],
            ),
            backgroundColor: const Color(0xFF1D00FF),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            const CustomTopBar(showProfile: false),
            Expanded(
              child: _isLoading
                  ? const AppLoadingIndicator()
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          // ── Avatar + Intestazione ──
                          _buildHeader(),
                          const SizedBox(height: 28),
                          // ── Sezione dati personali ──
                          _buildSectionTitle('Dati Personali'),
                          const SizedBox(height: 8),
                          _buildEditableCard(),
                          const SizedBox(height: 24),
                          // ── Sezione account ──
                          _buildSectionTitle('Account'),
                          const SizedBox(height: 8),
                          _buildAccountCard(),
                          const SizedBox(height: 24),
                          // ── Preferiti ──
                          if (_preferiti.isNotEmpty) ...[
                            _buildSectionTitle('I Tuoi Preferiti'),
                            const SizedBox(height: 8),
                            ..._preferiti.map((p) {
                              final locale = p['locali'] as Map<String, dynamic>?;
                              if (locale == null) return const SizedBox.shrink();
                              return _buildPreferitoCard(locale);
                            }),
                          ],
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const SharedFooter(currentIndex: -1),
    );
  }

  // ── Header con avatar e nome ──
  Widget _buildHeader() {
    final nome = _nomeCtrl.text;
    final cognome = _cognomeCtrl.text;
    final initials = [
      if (nome.isNotEmpty) nome[0].toUpperCase(),
      if (cognome.isNotEmpty) cognome[0].toUpperCase(),
    ].join();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Avatar circolare con gradiente
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF1D00FF), Color(0xFF7B2FFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1D00FF).withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              initials.isNotEmpty ? initials : '?',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [nome, cognome].where((s) => s.isNotEmpty).join(' ').isNotEmpty
                      ? [nome, cognome].where((s) => s.isNotEmpty).join(' ')
                      : 'Il tuo profilo',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _emailCtrl.text,
                  style: GoogleFonts.inter(color: Colors.white54, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        title,
        style: GoogleFonts.inter(
          color: Colors.white70,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  // ── Card dati personali editabili ──
  Widget _buildEditableCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          _buildCardField(
            icon: Icons.person_outline,
            label: 'Nome',
            controller: _nomeCtrl,
          ),
          _divider(),
          _buildCardField(
            icon: Icons.person_outline,
            label: 'Cognome',
            controller: _cognomeCtrl,
          ),
          _divider(),
          _buildCardField(
            icon: Icons.cake_outlined,
            label: 'Data di nascita',
            controller: _dataNascitaCtrl,
            readOnly: true,
            onTap: _pickDate,
            suffix: const Icon(Icons.calendar_today, color: Colors.white38, size: 18),
          ),
          _divider(),
          // Email (read-only con icona di conferma)
          _buildCardField(
            icon: Icons.email_outlined,
            label: 'Email',
            controller: _emailCtrl,
            readOnly: true,
            suffix: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified, color: Colors.greenAccent, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Verificata',
                        style: GoogleFonts.inter(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Pulsante salva (appare solo se ci sono modifiche)
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            child: _hasChanges
                ? Column(
                    children: [
                      _divider(),
                      InkWell(
                        onTap: _isSaving ? null : _saveProfile,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(14),
                          bottomRight: Radius.circular(14),
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1D00FF), Color(0xFF4D2FFF)],
                            ),
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(14),
                              bottomRight: Radius.circular(14),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: _isSaving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.save_rounded, color: Colors.white, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Salva Modifiche',
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildCardField({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    bool readOnly = false,
    VoidCallback? onTap,
    Widget? suffix,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF1D00FF), size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  TextField(
                    controller: controller,
                    readOnly: readOnly,
                    onTap: onTap,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    cursorColor: const Color(0xFF1D00FF),
                  ),
                ],
              ),
            ),
            if (suffix != null) suffix,
          ],
        ),
      ),
    );
  }

  Widget _divider() => const Divider(height: 1, color: Colors.white10, indent: 50);

  // ── Card account (password, ordini, logout) ──
  Widget _buildAccountCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          _buildActionTile(
            icon: Icons.receipt_long_outlined,
            label: 'Riepilogo Ordini',
            onTap: () => NavigatorService.pushNamed(AppRoutes.ordersScreen),
          ),
          _divider(),
          _buildActionTile(
            icon: Icons.lock_outline,
            label: 'Cambia Password',
            subtitle: 'Ricevi email di reset',
            onTap: _changePassword,
          ),
          _divider(),
          _buildActionTile(
            icon: Icons.logout,
            label: 'Disconnetti',
            color: Colors.redAccent,
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF1A1A1A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  title: Text('Disconnetti', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                  content: Text('Sei sicuro di voler uscire dal tuo account?', style: GoogleFonts.inter(color: Colors.white70)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text('Annulla', style: GoogleFonts.inter(color: Colors.white54)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text('Esci', style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await Supabase.instance.client.auth.signOut();
                NavigatorService.pushNamedAndRemoveUntil(AppRoutes.authenticationScreen);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    String? subtitle,
    Color color = Colors.white,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color == Colors.white ? const Color(0xFF1D00FF) : color, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: GoogleFonts.inter(color: color, fontSize: 15, fontWeight: FontWeight.w500)),
                  if (subtitle != null)
                    Text(subtitle, style: GoogleFonts.inter(color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color.withValues(alpha: 0.4), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPreferitoCard(Map<String, dynamic> locale) {
    final nome = locale['nome'] ?? '';
    final fotoUrl = locale['foto_url'] as String?;

    return GestureDetector(
      onTap: () => NavigatorService.pushNamed(
        AppRoutes.clubDetailScreen,
        arguments: {'id': locale['id']},
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        height: 120,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: const Color(0xFF1A1A1A),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (fotoUrl != null)
                CachedNetworkImage(
                  imageUrl: fotoUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) =>
                      Container(color: const Color(0xFF1A1A1A)),
                )
              else
                Container(color: const Color(0xFF1A1A1A)),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                  ),
                ),
              ),
              Positioned(
                left: 14,
                bottom: 14,
                child: Text(
                  nome,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
