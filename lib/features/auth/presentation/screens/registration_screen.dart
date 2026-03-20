import 'package:flutter/material.dart';

import '../../../teams/domain/entities/team.dart';
import '../../../teams/domain/exceptions/auth_email_already_in_use.dart';
import '../../../teams/domain/exceptions/team_id_already_exists.dart';
import '../../../teams/domain/repositories/team_repository.dart';
import '../widgets/dotted_background.dart';

/// Squad registration — pairs with [LoginScreen] (“Login to Dashboard” / “Register”).
class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({
    super.key,
    required this.teamRepository,
    this.onLoginTap,
  });

  final TeamRepository teamRepository;
  final VoidCallback? onLoginTap;

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  final _teamNameController = TextEditingController();
  final _teamIdController = TextEditingController();
  final _captainNameController = TextEditingController();
  final _captainEmailController = TextEditingController();
  final _member2Controller = TextEditingController();
  final _member3Controller = TextEditingController();
  final _member4Controller = TextEditingController();
  final _teamPasswordController = TextEditingController();

  bool _obscureTeamPassword = true;
  bool _submitting = false;

  static const _bg = Color(0xFF0A0E14);
  static const _neon = Color(0xFF62FF62);
  static const _card = Color(0xFF161B22);
  static const _fieldFill = Color(0xFF21262D);

  static const _labelStyle = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.bold,
    fontSize: 14,
  );
  static const _bodyStyle = TextStyle(
    color: Colors.white70,
    fontSize: 13,
    height: 1.4,
  );

  static final _teamIdPattern = RegExp(r'^[a-zA-Z0-9_]+$');

  @override
  void dispose() {
    _teamNameController.dispose();
    _teamIdController.dispose();
    _captainNameController.dispose();
    _captainEmailController.dispose();
    _member2Controller.dispose();
    _member3Controller.dispose();
    _member4Controller.dispose();
    _teamPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    final signup = Team.signup(
      teamName: _teamNameController.text,
      teamId: _teamIdController.text,
      captainName: _captainNameController.text,
      password: _teamPasswordController.text,
      captainEmail: _captainEmailController.text,
      member2Email: _member2Controller.text,
      member3Email: _member3Controller.text,
      member4Email: _member4Controller.text.trim().isEmpty ? null : _member4Controller.text,
    );
    try {
      await widget.teamRepository.registerTeam(signup);
      if (!mounted) return;
      final loginEmail = Team.firebaseAuthEmailFromTeamName(_teamNameController.text.trim());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Squad registered. Log in with $loginEmail and your team password.'),
        ),
      );
      if (widget.onLoginTap != null) {
        widget.onLoginTap!();
      } else {
        Navigator.of(context).pop();
      }
    } on TeamIdAlreadyExistsException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This team ID is already registered. Choose another.')),
      );
    } on AuthEmailAlreadyInUseException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'That team name already maps to a login email. Change the team name or sign in instead.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not register: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String? _required(String? v, String message) {
    if (v == null || v.trim().isEmpty) return message;
    return null;
  }

  String? _email(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return 'Required';
    if (!RegExp(r'^[\w.+-]+@[\w.-]+\.\w{2,}$').hasMatch(t)) return 'Enter a valid email';
    return null;
  }

  String? _optionalEmail(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return null;
    if (!RegExp(r'^[\w.+-]+@[\w.-]+\.\w{2,}$').hasMatch(t)) return 'Enter a valid email';
    return null;
  }

  String? _teamIdValidator(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return 'Team ID is required';
    if (t.length < 3) return 'At least 3 characters';
    if (!_teamIdPattern.hasMatch(t)) {
      return 'Letters, numbers, and underscores only';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          const Positioned.fill(child: DottedBackground()),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 32),
                  _buildCaptainMandate(),
                  const SizedBox(height: 24),
                  _buildEmailMandate(),
                  const SizedBox(height: 24),
                  _buildSquadSizeInfo(),
                  const SizedBox(height: 32),
                  _buildLoginLink(context),
                  const SizedBox(height: 40),
                  _buildRegistrationForm(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          icon: const Icon(Icons.arrow_back_ios_new, color: _neon, size: 20),
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BUILD YOUR',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                'DYNASTY.',
                style: TextStyle(
                  color: _neon,
                  fontSize: 40,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 8),
              SizedBox(
                height: 3,
                width: 60,
                child: DecoratedBox(decoration: BoxDecoration(color: _neon)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCaptainMandate() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildIconBox(Icons.shield_outlined, Colors.yellow.shade700),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("CAPTAIN'S MANDATE", style: _labelStyle),
              SizedBox(height: 4),
              Text(
                "As Captain, you are responsible for registering your entire squad and managing bidding credentials.",
                style: _bodyStyle,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmailMandate() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildIconBox(Icons.email_outlined, Colors.blue.shade700),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('EMAIL MANDATE', style: _labelStyle),
              SizedBox(height: 4),
              Text(
                'Enter the email addresses of your squad members. These will be used to sign in using google single sign on.',
                style: _bodyStyle,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSquadSizeInfo() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildIconBox(Icons.groups_outlined, Colors.greenAccent),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SQUAD SIZE', style: _labelStyle),
              SizedBox(height: 4),
              Text(
                'Enter 3 to 4 team members. Choose wisely; these are your strategic partners for the auction floor.',
                style: _bodyStyle,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoginLink(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ALREADY REGISTERED?',
          style: _labelStyle.copyWith(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: widget.onLoginTap ?? () => Navigator.of(context).maybePop(),
          child: const Row(
            children: [
              Text(
                'Login to Dashboard',
                style: TextStyle(
                  color: _neon,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              Icon(Icons.arrow_forward, color: _neon, size: 18),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRegistrationForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '01. TEAM IDENTITY',
              style: TextStyle(
                color: Colors.amber,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            _labeledField(
              label: 'TEAM NAME',
              hint: 'e.g. Mumbai Mavericks',
              icon: Icons.sports_cricket,
              controller: _teamNameController,
              validator: (v) => _required(v, 'Team name is required'),
            ),
            _labeledField(
              label: 'USER NAME (TEAM ID)',
              hint: 'mavericks_2024',
              icon: Icons.badge_outlined,
              controller: _teamIdController,
              validator: _teamIdValidator,
            ),
            const SizedBox(height: 20),
            const Text(
              '02. CAPTAIN IDENTITY',
              style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _labeledField(
              label: 'CAPTAIN NAME',
              hint: 'e.g. M.S. Dhoni',
              icon: Icons.sports_cricket,
              controller: _captainNameController,
              validator: (v) => _required(v, 'Captain name is required'),
            ),
            const SizedBox(height: 20),
            const Text(
              '03. SQUAD EMAILS',
              style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _labeledField(
              label: 'CAPTAIN EMAIL',
              hint: 'Captain — first in squad list',
              icon: Icons.email_outlined,
              controller: _captainEmailController,
              keyboardType: TextInputType.emailAddress,
              validator: _email,
            ),
            _labeledField(
              label: 'MEMBER 2 EMAIL',
              hint: 'squad@email.com',
              icon: Icons.email_outlined,
              controller: _member2Controller,
              keyboardType: TextInputType.emailAddress,
              validator: _email,
            ),
            _labeledField(
              label: 'MEMBER 3 EMAIL',
              hint: 'squad@email.com',
              icon: Icons.email_outlined,
              controller: _member3Controller,
              keyboardType: TextInputType.emailAddress,
              validator: _email,
            ),
            _labeledField(
              label: 'MEMBER 4 EMAIL (OPTIONAL)',
              hint: 'squad@email.com',
              icon: Icons.email_outlined,
              controller: _member4Controller,
              keyboardType: TextInputType.emailAddress,
              validator: _optionalEmail,
            ),
            const SizedBox(height: 20),
            const Text(
              '04. TEAM PASSWORD',
              style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildTeamPasswordField(),
            const SizedBox(height: 24),
            _buildRegisterButton(),
          ],
        ),
      ),
    );
  }

  Widget _labeledField({
    required String label,
    required String hint,
    required TextEditingController controller,
    IconData? icon,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label.isNotEmpty) ...[
            Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
          ],
          TextFormField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            keyboardType: keyboardType,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: validator,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
              prefixIcon: icon != null ? Icon(icon, color: Colors.white24, size: 20) : null,
              filled: true,
              fillColor: _fieldFill,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              errorStyle: const TextStyle(color: Colors.orangeAccent, fontSize: 11),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamPasswordField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: _teamPasswordController,
        obscureText: _obscureTeamPassword,
        obscuringCharacter: '*',
        style: const TextStyle(color: Colors.white),
        autovalidateMode: AutovalidateMode.onUserInteraction,
        validator: (value) {
          final v = value ?? '';
          if (v.isEmpty) return 'Team password is required';
          if (v.length < 12) return 'Minimum 12 characters';
          return null;
        },
        decoration: InputDecoration(
          hintText: 'At least 12 characters',
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
          prefixIcon: const Icon(Icons.lock_outlined, color: Colors.white24, size: 20),
          suffixIcon: IconButton(
            onPressed: () => setState(() => _obscureTeamPassword = !_obscureTeamPassword),
            icon: Icon(
              _obscureTeamPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              color: Colors.white38,
              size: 20,
            ),
          ),
          filled: true,
          fillColor: _fieldFill,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          errorStyle: const TextStyle(color: Colors.orangeAccent, fontSize: 11),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildRegisterButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _submitting ? null : _submit,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          width: double.infinity,
          height: 55,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              colors: _submitting
                  ? [Colors.grey.shade700, Colors.grey.shade800]
                  : const [_neon, Color(0xFF32CD32)],
            ),
            boxShadow: [
              if (!_submitting)
                BoxShadow(
                  color: _neon.withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_submitting) ...[
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _neon.withValues(alpha: 0.9)),
                ),
                const SizedBox(width: 12),
              ],
              Text(
                _submitting ? 'REGISTERING…' : 'REGISTER SQUAD',
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              if (!_submitting) ...[
                const SizedBox(width: 8),
                Icon(Icons.stadium, color: Colors.black.withValues(alpha: 0.7)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconBox(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }
}
