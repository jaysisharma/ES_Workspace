import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/domain/entities/user_entity.dart';
import 'package:order_app/presentation/providers/settings_provider.dart';
import 'package:order_app/presentation/providers/user_providers.dart';

class AddUserScreen extends ConsumerStatefulWidget {
  const AddUserScreen({super.key});

  @override
  ConsumerState<AddUserScreen> createState() => _AddUserScreenState();
}

class _AddUserScreenState extends ConsumerState<AddUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  UserRole _selectedRole = UserRole.staff;
  bool _accountActive = true;
  bool _obscurePassword = true;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _saveUser() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      // 1. Create the Firebase Auth account (this sets the password)
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      final uid = credential.user!.uid;
      final roleString = _selectedRole.name.toLowerCase();

      // 2. Write the Firestore user document with the real Auth UID
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'id': uid,
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'role': roleString,
        'isActive': _accountActive,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3. Refresh local user list
      await ref.read(userNotifierProvider.notifier).refresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('User account created successfully!'),
            backgroundColor: const Color(0xFF10b981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        );
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Failed to create account'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final isDarkMode = settings.themeMode == ThemeMode.dark;

    // Design tokens
    final primaryColor = const Color(0xFF0075db);
    final bgColor = isDarkMode
        ? const Color(0xFF0f172a)
        : const Color(0xFFf5f7f8);
    final cardColor = isDarkMode ? const Color(0xFF1e293b) : Colors.white;
    final borderColor = isDarkMode
        ? const Color(0xFF1e293b).withValues(alpha: 0.8)
        : const Color(0xFFe2e8f0);
    final textColor = isDarkMode ? Colors.white : const Color(0xFF0f172a);
    final labelColor = isDarkMode
        ? const Color(0xFF94a3b8)
        : const Color(0xFF64748b);
    final dividerColor = isDarkMode
        ? const Color(0xFF334155).withValues(alpha: 0.3)
        : const Color(0xFFf1f5f9);

    // Avatar placeholder from name initials
    final name = _nameController.text.trim();
    final initials = name.isEmpty
        ? '?'
        : name
              .split(' ')
              .where((w) => w.isNotEmpty)
              .take(2)
              .map((w) => w[0].toUpperCase())
              .join();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: AppBar(
          backgroundColor: bgColor.withValues(alpha: 0.8),
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: textColor, size: 22),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Add User',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
              fontFamily: 'Manrope',
            ),
          ),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(color: borderColor, height: 1),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Form(
          key: _formKey,
          onChanged: () => setState(() {}), // refresh initials live
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Avatar Preview ────────────────────────────────────────
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        primaryColor,
                        primaryColor.withValues(alpha: 0.6),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Profile initials auto-generated',
                  style: TextStyle(fontSize: 11, color: labelColor),
                ),
              ),
              const SizedBox(height: 24),

              // ── Basic Information ─────────────────────────────────────
              _buildSectionTitle('Basic Information', labelColor),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: _cardDecoration(cardColor, borderColor),
                child: Column(
                  children: [
                    _buildTextField(
                      controller: _nameController,
                      label: 'Full Name',
                      hint: 'e.g. Ram Bahadur',
                      icon: Icons.person_outline_rounded,
                      isDarkMode: isDarkMode,
                      textColor: textColor,
                      labelColor: labelColor,
                      borderColor: borderColor,
                      primaryColor: primaryColor,
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _emailController,
                      label: 'Email Address',
                      hint: 'ram@eventsolution.com',
                      icon: Icons.email_outlined,
                      isDarkMode: isDarkMode,
                      textColor: textColor,
                      labelColor: labelColor,
                      borderColor: borderColor,
                      primaryColor: primaryColor,
                      validator: (value) =>
                          value == null || !value.contains('@')
                          ? 'Invalid email'
                          : null,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _phoneController,
                      label: 'Phone Number',
                      hint: '+977 98...',
                      icon: Icons.phone_outlined,
                      isDarkMode: isDarkMode,
                      textColor: textColor,
                      labelColor: labelColor,
                      borderColor: borderColor,
                      primaryColor: primaryColor,
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Security (Temp Password) ───────────────────────────────
              _buildSectionTitle('Account Security', labelColor),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: _cardDecoration(cardColor, borderColor),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Temporary Password',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: TextStyle(color: textColor, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Min 6 characters',
                        hintStyle: TextStyle(
                          color: labelColor.withValues(alpha: 0.5),
                        ),
                        filled: true,
                        fillColor: isDarkMode
                            ? const Color(0xFF0f172a)
                            : const Color(0xFFf8fafc),
                        prefixIcon: Icon(
                          Icons.lock_outline_rounded,
                          color: labelColor,
                          size: 20,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: labelColor,
                            size: 20,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(
                            color: primaryColor.withValues(alpha: 0.5),
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(color: Colors.red),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(color: Colors.red),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Required';
                        if (value.length < 6) return 'At least 6 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 13,
                          color: labelColor,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'The user can change this password after logging in.',
                            style: TextStyle(fontSize: 11, color: labelColor),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Role & Status ─────────────────────────────────────────
              _buildSectionTitle('Role & Status', labelColor),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: _cardDecoration(cardColor, borderColor),
                child: Column(
                  children: [
                    _buildRow(
                      title: 'Role',
                      textColor: textColor,
                      child: _buildRoleDropdown(
                        isDarkMode,
                        primaryColor,
                        cardColor,
                        textColor,
                        labelColor,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Divider(color: dividerColor),
                    ),
                    _buildRow(
                      title: 'Account Active',
                      textColor: textColor,
                      child: _buildSwitch(
                        _accountActive,
                        (val) => setState(() => _accountActive = val),
                        primaryColor,
                        isDarkMode,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveUser,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  disabledBackgroundColor: primaryColor.withValues(alpha: 0.5),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Create User Account',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration(Color cardColor, Color borderColor) {
    return BoxDecoration(
      color: cardColor,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: borderColor),
    );
  }

  Widget _buildSectionTitle(String title, Color labelColor) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: labelColor,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDarkMode,
    required Color textColor,
    required Color labelColor,
    required Color borderColor,
    required Color primaryColor,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: TextStyle(color: textColor, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: labelColor.withValues(alpha: 0.5)),
            prefixIcon: Icon(icon, color: labelColor, size: 20),
            filled: true,
            fillColor: isDarkMode
                ? const Color(0xFF0f172a)
                : const Color(0xFFf8fafc),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(
                color: primaryColor.withValues(alpha: 0.5),
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Colors.red),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildRow({
    required String title,
    required Color textColor,
    required Widget child,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        child,
      ],
    );
  }

  Widget _buildSwitch(
    bool value,
    ValueChanged<bool> onChanged,
    Color primaryColor,
    bool isDarkMode,
  ) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        width: 44,
        height: 24,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value
              ? primaryColor
              : (isDarkMode
                    ? const Color(0xFF334155)
                    : const Color(0xFFe2e8f0)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 18,
            height: 18,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleDropdown(
    bool isDarkMode,
    Color primaryColor,
    Color cardColor,
    Color textColor,
    Color labelColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF0f172a) : const Color(0xFFf1f5f9),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<UserRole>(
          value: _selectedRole,
          dropdownColor: cardColor,
          icon: Icon(Icons.keyboard_arrow_down, color: labelColor, size: 16),
          style: TextStyle(
            color: textColor,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
          onChanged: (UserRole? newVal) {
            if (newVal != null) {
              setState(() => _selectedRole = newVal);
            }
          },
          items: UserRole.values.map<DropdownMenuItem<UserRole>>((
            UserRole role,
          ) {
            return DropdownMenuItem<UserRole>(
              value: role,
              child: Text(role.name.toUpperCase()),
            );
          }).toList(),
        ),
      ),
    );
  }
}
