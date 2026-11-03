import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../config/supabase_config.dart';
import '../../screens/login_screen.dart';
import 'settings_header.dart';

import 'models/form_field_config.dart';
import 'models/inline_form_config.dart';
import 'widgets/inline_form_widget.dart';
import 'widgets/ratings_section.dart';
import 'widgets/communication_section.dart';
import 'widgets/password.dart';
import 'widgets/help_widget.dart';
import 'widgets/delete_account.dart';
import 'widgets/logout_section.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  /// ONLY ONE OPEN
  int? openIndex;

  late List<GlobalKey> sectionKeys;

  late List<InlineFormConfig> forms;

  void toggle(int index) {
    setState(() {
      openIndex = openIndex == index ? null : index;
    });

    if (openIndex != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        final ctx = sectionKeys[index].currentContext;
        if (ctx == null) return;

        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          alignment: 0.1,
        );
      });
    }
  }

  void showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text("Close Account"),
            content: const Text(
              "Are you sure you want to permanently delete your account?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  deleteAccount();
                },
                child: const Text("Delete"),
              ),
            ],
          ),
    );
  }

  Future<void> deleteAccount() async {
    try {
      await AuthService().deactivateAccount();
      await AuthService().signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete account: $e')),
        );
      }
    }
  }

  void showLogoutConfirmation() {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text("Logout"),
            content: const Text("Do you really want to logout?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  performLogout();
                },
                child: const Text("Logout"),
              ),
            ],
          ),
    );
  }

  void performLogout() async {
    try {
      // Perform sign out using AuthService
      // main.dart already listens to auth state changes and will automatically navigate to LoginScreen
      await AuthService().signOut();
    } catch (e) {
      // Supabase still clears the local session even if the network call to log out fails.
      // We ignore the error here to prevent showing technical fetch exceptions to the user.
      debugPrint('Logout offline or error: $e');
    }
  }

  /// OPEN A SECTION BY TITLE
  void openSection(String title) {
    final index = forms.indexWhere((form) => form.title == title);

    if (index == -1) return;

    setState(() {
      openIndex = index;
    });

    /// scroll AFTER rebuild (safe)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final ctx = sectionKeys[index].currentContext;
      if (ctx == null) return;

      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        alignment: 0.1,
      );
    });
  }

  /// CLOSE DELETE SECTION
  void collapseDeleteSection() {
    setState(() {
      openIndex = null;
    });
  }

  /// DATA STATE
  Map<String, bool> commPrefs = {
    "Push notification": true,
    "Emails": true,
    "Text messages": true,
    "Phone calls": true,
  };

  List<dynamic>? receivedRatings;
  List<dynamic>? givenRatings;
  List<dynamic>? rateableBookings;
  double? averageRating;
  int? ratingCount;
  String? firstName;
  Map<String, dynamic>? userProfile;
  Map<String, dynamic>? vehicle;

  @override
  void initState() {
    super.initState();
    _initializeForms();
    _loadUserData();
  }

  void _initializeForms({
    String? firstName,
    String? lastName,
    String? dob,
    String? email,
    String? mobile,
    Map<String, dynamic>? vehicle,
    Map<String, dynamic>? profile,
  }) {
    forms = [
      InlineFormConfig(
        title: "Personal Details",
        icon: Icons.person,
        fields: [
          FormFieldConfig(label: "First name", initialValue: firstName),
          FormFieldConfig(label: "Last name", initialValue: lastName),

          FormFieldConfig(
            label: "Date of birth",
            type: FieldType.date,
            initialValue: dob,
          ),

          FormFieldConfig(
            label: "Email",
            type: FieldType.email,
            initialValue: email,
            readOnly: true,
          ),

          FormFieldConfig(
            label: "Mobile Number",
            type: FieldType.phone,
            initialValue: mobile,
          ),

          FormFieldConfig(label: "About you", type: FieldType.multiline),
        ],
        onSave: (data) async {
          await AuthService().updateProfile(
            firstName: data["First name"],
            lastName: data["Last name"],
            mobile: data["Mobile Number"],
          );

          if (data["Date of birth"] != null) {
            await SupabaseConfig.client
                .from('profiles')
                .update({'dob': data["Date of birth"]})
                .eq('id', SupabaseConfig.userId!);
          }
        },
      ),

      InlineFormConfig(
        title: "Vehicle Details",
        icon: Icons.directions_car,
        fields: [
          FormFieldConfig(
            label: "Vehicle Brand",
            initialValue: vehicle?['make'],
          ),
          FormFieldConfig(
            label: "Vehicle Model",
            initialValue: vehicle?['model'],
          ),
          FormFieldConfig(
            label: "Vehicle Color",
            initialValue: vehicle?['color'],
          ),
          FormFieldConfig(
            label: "Vehicle Registration Number",
            initialValue: vehicle?['plate_number'],
          ),
          FormFieldConfig(
            label: "Seating Capacity",
            type: FieldType.number,
            initialValue: vehicle?['total_seats']?.toString(),
          ),
        ],
        onSave: (data) async {
          final userId = SupabaseConfig.userId;
          if (userId == null) return;

          final vehicleData = {
            'user_id': userId,
            'make': data["Vehicle Brand"],
            'model': data["Vehicle Model"],
            'color': data["Vehicle Color"],
            'plate_number': data["Vehicle Registration Number"],
            'total_seats': int.tryParse(data["Seating Capacity"] ?? "4") ?? 4,
            'vehicle_type': 'sedan', // default
          };

          // Check if vehicle exists
          final existing =
              await SupabaseConfig.client
                  .from('vehicles')
                  .select('id')
                  .eq('user_id', userId)
                  .maybeSingle();

          if (existing != null) {
            await SupabaseConfig.client
                .from('vehicles')
                .update(vehicleData)
                .eq('id', existing['id']);
          } else {
            await SupabaseConfig.client.from('vehicles').insert(vehicleData);
          }
        },
      ),

      InlineFormConfig(
        title: "Ratings",
        icon: Icons.star,
        showActions: false,
        fields: [],
        customChild: RatingsSection(
          receivedRatings: receivedRatings,
          givenRatings: givenRatings,
          rateableBookings: rateableBookings,
          onRefresh: _loadUserData,
        ),
      ),

      InlineFormConfig(
        title: "Communication Preference",
        icon: Icons.remove_circle,
        fields: [],
        customChild: CommunicationPreferenceWidget(
          values: commPrefs,
          onChanged: (key, val) {
            setState(() {
              commPrefs[key] = val;
            });
          },
        ),
        onSave: (data) async {
          await SupabaseConfig.client
              .from('profiles')
              .update({
                'comm_push_notifications': commPrefs["Push notification"],
                'comm_emails': commPrefs["Emails"],
                'comm_text_messages': commPrefs["Text messages"],
                'comm_phone_calls': commPrefs["Phone calls"],
              })
              .eq('id', SupabaseConfig.userId!);
        },
      ),

      InlineFormConfig(
        title: "Change Password",
        icon: Icons.remove_circle,
        showActions: false,
        fields: [],
        customChild: ChangePasswordSection(
          onCancel: () {
            collapseDeleteSection();
          },
        ),
      ),

      InlineFormConfig(
        title: "Postal Address",
        icon: Icons.remove_circle,
        fields: [
          FormFieldConfig(
            label: "Full Name",
            initialValue: profile?['postal_full_name'],
          ),
          FormFieldConfig(
            label: "Flat/Door/Block No.",
            initialValue: profile?['postal_address_line1'],
          ),
          FormFieldConfig(
            label: "Street/Locality/Area",
            initialValue: profile?['postal_address_line2'],
          ),
          FormFieldConfig(
            label: "Landmark (Optional)",
            initialValue: profile?['postal_landmark'],
          ),
          FormFieldConfig(
            label: "City/District",
            initialValue: profile?['postal_city'],
          ),
          FormFieldConfig(
            label: "State",
            initialValue: profile?['postal_state'],
          ),
          FormFieldConfig(
            label: "PIN Code",
            initialValue: profile?['postal_pincode'],
          ),
        ],
        onSave: (data) async {
          await SupabaseConfig.client
              .from('profiles')
              .update({
                'postal_full_name': data["Full Name"],
                'postal_address_line1': data["Flat/Door/Block No."],
                'postal_address_line2': data["Street/Locality/Area"],
                'postal_landmark': data["Landmark (Optional)"],
                'postal_city': data["City/District"],
                'postal_state': data["State"],
                'postal_pincode': data["PIN Code"],
              })
              .eq('id', SupabaseConfig.userId!);
        },
      ),

      InlineFormConfig(
        title: "Payment Method",
        icon: Icons.description,
        fields: [FormFieldConfig(label: "Payment Method")],
      ),

      InlineFormConfig(
        title: "Transaction History",
        icon: Icons.description,
        fields: [FormFieldConfig(label: "Transaction History")],
      ),

      InlineFormConfig(
        title: "Help",
        icon: Icons.help_outline,
        showActions: false,
        fields: [],
        customChild: HelpWidget(),
      ),

      InlineFormConfig(
        title: "Terms and Conditions",
        icon: Icons.description,
        showActions: false,
        fields: [FormFieldConfig(label: "Terms and Conditions")],
      ),

      InlineFormConfig(
        title: "Logout",
        icon: Icons.logout,
        showActions: false,
        fields: [],
        customChild: LogoutSection(
          onLogout: () {
            showLogoutConfirmation();
          },

          onCancel: () {
            collapseDeleteSection(); // reuse same close logic
          },
        ),
      ),

      InlineFormConfig(
        title: "Delete my account",
        icon: Icons.remove_circle_outline,
        showActions: false,
        fields: [],
        customChild: DeleteAccountHelpSection(
          /// PERSONAL DETAILS
          onUpdateProfile: () {
            openSection("Personal Details");
          },

          /// HELP PAGE
          onContactUs: () {
            openSection("Help");
          },

          /// COMMUNICATION PREF
          onCommunicationPrefs: () {
            openSection("Communication Preference");
          },

          /// DELETE ACCOUNT
          onCloseAccount: () {
            showDeleteConfirmation(context);
          },

          /// CANCEL
          onCancel: () {
            collapseDeleteSection();
          },
        ),
      ),
    ];
    sectionKeys = List.generate(forms.length, (_) => GlobalKey());
  }

  Future<void> _loadUserData() async {
    try {
      final userId = SupabaseConfig.userId;
      if (userId == null) return;

      final results = await Future.wait<dynamic>([
        AuthService().getCurrentProfile(),
        SupabaseConfig.client
            .from('vehicles')
            .select()
            .eq('user_id', userId)
            .maybeSingle(),
        SupabaseConfig.client
            .from('ratings')
            .select(
              '*, rater:profiles!rater_id(first_name, last_name, avatar_url)',
            )
            .eq('ratee_id', userId),
        SupabaseConfig.client
            .from('ratings')
            .select(
              '*, ratee:profiles!ratee_id(first_name, last_name, avatar_url)',
            )
            .eq('rater_id', userId),
        // Fetch completed bookings where user is passenger
        SupabaseConfig.client
            .from('bookings')
            .select('*, ride:rides(*, driver:profiles!driver_id(*)), passenger:profiles!passenger_id(*)')
            .eq('passenger_id', userId)
            .eq('status', 'completed'),
        // Fetch completed bookings where user is driver
        SupabaseConfig.client
            .from('bookings')
            .select('*, ride:rides!inner(*, driver:profiles!driver_id(*)), passenger:profiles!passenger_id(*)')
            .eq('rides.driver_id', userId)
            .eq('status', 'completed'),
      ]);

      userProfile = results[0] as Map<String, dynamic>?;
      vehicle = results[1] as Map<String, dynamic>?;
      receivedRatings = results[2] as List<dynamic>?;
      givenRatings = results[3] as List<dynamic>?;
      final passengerBookings = results[4] as List<dynamic>? ?? [];
      final driverBookings = results[5] as List<dynamic>? ?? [];
      
      final allCompletedBookings = [...passengerBookings, ...driverBookings];

      // Filter bookings that haven't been rated yet by the current user
      if (allCompletedBookings != null && givenRatings != null) {
        final ratedBookingIds =
            givenRatings!.map((r) => r['booking_id'].toString()).toSet();
        
        rateableBookings = allCompletedBookings.where((b) {
          // Verify user is actually part of this booking (driver or passenger)
          final isPassenger = b['passenger_id'] == userId;
          final isDriver = b['ride']['driver_id'] == userId;
          
          if (!isPassenger && !isDriver) return false;
          
          return !ratedBookingIds.contains(b['id'].toString());
        }).toList();
      }

      // Calculate Average Rating
      if (receivedRatings != null && receivedRatings!.isNotEmpty) {
        double total = 0;
        for (var r in receivedRatings!) {
          total += (r['rating'] as num?)?.toDouble() ?? 0.0;
        }
        averageRating = total / receivedRatings!.length;
        ratingCount = receivedRatings!.length;
      } else {
        averageRating = 0.0;
        ratingCount = 0;
      }

      final currentUser = SupabaseConfig.currentUser;

      if (!mounted) return;

      setState(() {
        if (userProfile != null) {
          firstName = userProfile!['first_name']?.toString();
          commPrefs = {
            "Push notification": userProfile!['comm_push_notifications'] ?? true,
            "Emails": userProfile!['comm_emails'] ?? true,
            "Text messages": userProfile!['comm_text_messages'] ?? true,
            "Phone calls": userProfile!['comm_phone_calls'] ?? true,
          };
        }

        _initializeForms(
          firstName: userProfile?['first_name']?.toString(),
          lastName: userProfile?['last_name']?.toString(),
          dob: userProfile?['dob']?.toString(),
          email: currentUser?.email,
          mobile: userProfile?['mobile']?.toString(),
          vehicle: vehicle,
          profile: userProfile,
        );
      });
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          children: [
            SettingsHeader(
              profile: userProfile,
              vehicle: vehicle,
              averageRating: averageRating,
              ratingCount: ratingCount,
              onProfileUpdated: _loadUserData,
            ),

            ...List.generate(
              forms.length,
              (index) => Container(
                key: sectionKeys[index],
                child: InlineForm(
                  config: forms[index],
                  isOpen: openIndex == index,
                  onTap: () => toggle(index),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
