import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileStorageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Collection reference
  final CollectionReference _profilesCollection = 
      FirebaseFirestore.instance.collection('user_profiles');

  // Store profile data to Firestore
  Future<bool> saveProfile({
    required String disabilityType,
    required String name,
    String? email,
    String? address,
    String? phone,
    String? emergencyContact,
    String? preferredLanguage,
  }) async {
    try {
      // Get current user ID (if authenticated) or generate a unique ID
      String userId = _auth.currentUser?.uid ?? 
          DateTime.now().millisecondsSinceEpoch.toString();
      
      // Create profile data map
      Map<String, dynamic> profileData = {
        'userId': userId,
        'disabilityType': disabilityType,
        'name': name,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
      };

      // Add fields based on disability type
      switch (disabilityType) {
        case 'Cognitive Disability':
          profileData.addAll({
            'email': email ?? '',
            'address': address ?? '',
            'phone': phone ?? '',
          });
          break;
          
        case 'Vision Disability':
        case 'Physical Disability':
          profileData.addAll({
            'emergencyContact': emergencyContact ?? '',
            'preferredLanguage': preferredLanguage ?? '',
          });
          break;
          
        case 'Hearing Disability':
        case 'Speech Disability':
          profileData.addAll({
            'email': email ?? '',
            'address': address ?? '',
            'phone': phone ?? '',
            'emergencyContact': emergencyContact ?? '',
            'preferredLanguage': preferredLanguage ?? '',
          });
          break;
      }

      // Save to Firestore
      await _profilesCollection.doc(userId).set(profileData);
      
      print('Profile saved successfully for user: $userId');
      return true;
      
    } catch (e) {
      print('Error saving profile: $e');
      return false;
    }
  }

  // Retrieve profile data
  Future<Map<String, dynamic>?> getProfile(String userId) async {
    try {
      DocumentSnapshot doc = await _profilesCollection.doc(userId).get();
      
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
      
    } catch (e) {
      print('Error retrieving profile: $e');
      return null;
    }
  }

  // Update profile data
  Future<bool> updateProfile(String userId, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      
      await _profilesCollection.doc(userId).update(updates);
      
      print('Profile updated successfully for user: $userId');
      return true;
      
    } catch (e) {
      print('Error updating profile: $e');
      return false;
    }
  }

  // Delete profile
  Future<bool> deleteProfile(String userId) async {
    try {
      await _profilesCollection.doc(userId).delete();
      
      print('Profile deleted successfully for user: $userId');
      return true;
      
    } catch (e) {
      print('Error deleting profile: $e');
      return false;
    }
  }

  // Get all profiles (for admin purposes)
  Future<List<Map<String, dynamic>>> getAllProfiles() async {
    try {
      QuerySnapshot querySnapshot = await _profilesCollection
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();
      
      return querySnapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data() as Map<String, dynamic>,
              })
          .toList();
      
    } catch (e) {
      print('Error retrieving all profiles: $e');
      return [];
    }
  }

  // Get profiles by disability type
  Future<List<Map<String, dynamic>>> getProfilesByDisabilityType(String disabilityType) async {
    try {
      QuerySnapshot querySnapshot = await _profilesCollection
          .where('disabilityType', isEqualTo: disabilityType)
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();
      
      return querySnapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data() as Map<String, dynamic>,
              })
          .toList();
      
    } catch (e) {
      print('Error retrieving profiles by disability type: $e');
      return [];
    }
  }
}

// Integration with your existing _submitForm method
class ProfileFormIntegration {
  final ProfileStorageService _storageService = ProfileStorageService();
  
  Future<void> submitFormToFirestore({
    required String disabilityType,
    required TextEditingController nameController,
    required TextEditingController emailController,
    required TextEditingController addressController,
    required TextEditingController phoneController,
    required TextEditingController emergencyContactController,
    required TextEditingController languageController,
    required BuildContext context,
    required FlutterTts? flutterTts,
    required bool supportsVoice,
  }) async {
    bool loadingDialogShown = false;
    try {
      // Show loading indicator
      loadingDialogShown = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Center(
            child: CircularProgressIndicator(),
          );
        },
      );

      // Save profile to Firestore with timeout
      bool success = await _storageService.saveProfile(
        disabilityType: disabilityType,
        name: nameController.text.trim(),
        email: emailController.text.trim(),
        address: addressController.text.trim(),
        phone: phoneController.text.trim(),
        emergencyContact: emergencyContactController.text.trim(),
        preferredLanguage: languageController.text.trim(),
      ).timeout(Duration(seconds: 15), onTimeout: () {
        print('Firestore saveProfile timed out');
        return false;
      });

      // Hide loading indicator
      if (loadingDialogShown) {
        Navigator.of(context).pop();
        loadingDialogShown = false;
      }

      if (success) {
        if (supportsVoice && flutterTts != null) {
          await flutterTts.speak("Profile saved successfully to database! Thank you for completing the form.");
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Profile Saved Successfully to Database!"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        if (supportsVoice && flutterTts != null) {
          await flutterTts.speak("Sorry, there was an error saving your profile. Please try again.");
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error saving profile. Please try again."),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // Hide loading indicator if still showing
      if (loadingDialogShown) {
        Navigator.of(context).pop();
        loadingDialogShown = false;
      }
      
      print('Error in submitFormToFirestore: $e');
      
      if (supportsVoice && flutterTts != null) {
        await flutterTts.speak("Sorry, there was an error saving your profile. Please try again.");
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error saving profile. Please try again."),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }
}
void main() {
  runApp(MaterialApp(
    home: SetupProfilePage(selectedDisability: 'Hearing Disability'), // change here for testing
    debugShowCheckedModeBanner: false,
  ));
}

class SetupProfilePage extends StatefulWidget {
  final String selectedDisability;
  const SetupProfilePage({required this.selectedDisability, Key? key}) : super(key: key);

  @override
  State<SetupProfilePage> createState() => _SetupProfilePageState();
}

class _SetupProfilePageState extends State<SetupProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late FlutterTts flutterTts;
  late stt.SpeechToText speech;
  
  bool isListening = false;
  bool speechEnabled = false;
  String lastWords = '';
  bool isWaitingForNavigationCommand = false;
  bool hasGivenInitialInstructions = false;
  
  // Timer for auto-restart listening
  Timer? _listeningTimer;
  Timer? _inactivityTimer;
  DateTime? _lastInputTime;
  int _promptCount = 0;
  static const int maxPrompts = 3;
  static const int listeningDuration = 12; // seconds
  static const int inactivityTimeout = 10; // seconds

  // Controllers
  final nameController = TextEditingController();
  final emergencyContactController = TextEditingController();
  final languageController = TextEditingController();
  final emailController = TextEditingController();
  final addressController = TextEditingController();
  final phoneController = TextEditingController();

  int currentFieldIndex = 0;

  // Check if disability type supports voice features
  bool get supportsVoice => !['Hearing Disability', 'Speech Disability'].contains(widget.selectedDisability);

  // Field data for all disability types
  Map<String, List<Map<String, dynamic>>> fieldData = {
    'Cognitive Disability': [
      {
        'label': 'Enter your Name',
        'instruction': 'Please enter your full name. You can type or speak your answer. ',
        'hint': 'Your full name',
        'controller': null,
        'keyboardType': TextInputType.text,
        'field_type': 'name',
      },
      {
        'label': 'Enter your Email',
        'instruction': 'Please enter your email address for contact purposes. You can type or speak your answer.',
        'hint': 'your.email@example.com',
        'controller': null,
        'keyboardType': TextInputType.emailAddress,
        'field_type': 'email',
      },
      {
        'label': 'Enter your Address',
        'instruction': 'Please enter your home address. You can type or speak your answer.',
        'hint': 'Your home address',
        'controller': null,
        'keyboardType': TextInputType.text,
        'field_type': 'address',
      },
      {
        'label': 'Enter your Phone Number',
        'instruction': 'Please enter your phone number for emergency contact. You can type or speak your answer.',
        'hint': 'Your phone number',
        'controller': null,
        'keyboardType': TextInputType.phone,
        'field_type': 'phone',
      },
    ],
    'Vision Disability': [
      {
        'label': 'Enter your Name',
        'instruction': 'Please enter your full name. You can type or speak your answer.',
        'hint': 'Your full name',
        'controller': null,
        'keyboardType': TextInputType.text,
      },
      {
        'label': 'Emergency Contact Number',
        'instruction': 'Please enter your emergency contact number. You can type or speak your answer.',
        'hint': 'Emergency contact number',
        'controller': null,
        'keyboardType': TextInputType.phone,
      },
      {
        'label': 'Preferred Language',
        'instruction': 'Please enter your preferred language. You can type or speak your answer.',
        'hint': 'Your preferred language',
        'controller': null,
        'keyboardType': TextInputType.text,
      },
    ],
    'Physical Disability': [
      {
        'label': 'Enter your Name',
        'instruction': 'Please enter your full name. You can type or speak your answer.',
        'hint': 'Your full name',
        'controller': null,
        'keyboardType': TextInputType.text,
      },
      {
        'label': 'Emergency Contact Number',
        'instruction': 'Please enter your emergency contact number. You can type or speak your answer.',
        'hint': 'Emergency contact number',
        'controller': null,
        'keyboardType': TextInputType.phone,
      },
      {
        'label': 'Preferred Language',
        'instruction': 'Please enter your preferred language. You can type or speak your answer.',
        'hint': 'Your preferred language',
        'controller': null,
        'keyboardType': TextInputType.text,
      },
    ],
    'Hearing Disability': [
  {
    'label': 'Enter your Name',
    'instruction': 'Please enter your full name using the keyboard.',
    'hint': 'Your full name',
    'controller': null,
    'keyboardType': TextInputType.text,
    'field_type': 'name',  // Add this identifier
  },
  {
    'label': 'Enter your Email',
    'instruction': 'Please enter your email address for contact purposes.',
    'hint': 'your.email@example.com',
    'controller': null,
    'keyboardType': TextInputType.emailAddress,
    'field_type': 'email',  // Add this identifier
  },
  {
    'label': 'Enter your Address',
    'instruction': 'Please enter your home address.',
    'hint': 'Your home address',
    'controller': null,
    'keyboardType': TextInputType.text,
    'field_type': 'address',  // Add this identifier
  },
  {
    'label': 'Enter your Phone Number',
    'instruction': 'Please enter your phone number for emergency contact.',
    'hint': 'Your phone number',
    'controller': null,
    'keyboardType': TextInputType.phone,
    'field_type': 'phone',  // Add this identifier
  },
  {
    'label': 'Emergency Contact Number',
    'instruction': 'Please enter your emergency contact number using the keyboard.',
    'hint': 'Emergency contact number',
    'controller': null,
    'keyboardType': TextInputType.phone,
    'field_type': 'emergency_contact',  // Add this identifier
  },
  {
    'label': 'Preferred Language',
    'instruction': 'Please enter your preferred language using the keyboard.',
    'hint': 'Your preferred language',
    'controller': null,
    'keyboardType': TextInputType.text,
    'field_type': 'language',  // Add this identifier
  },
],
    'Speech Disability': [
      {
        'label': 'Enter your Name',
        'instruction': 'Please enter your full name using the keyboard.',
        'hint': 'Your full name',
        'controller': null,
        'keyboardType': TextInputType.text,
        'field_type': 'name',
        
      },
      {
        'label': 'Enter your Email',
        'instruction': 'Please enter your email address for contact purposes.',
        'hint': 'your.email@example.com',
        'controller': null,
        'keyboardType': TextInputType.emailAddress,
        'field_type': 'email',
      },
      {
        'label': 'Enter your Address',
        'instruction': 'Please enter your home address.',
        'hint': 'Your home address',
        'controller': null,
        'keyboardType': TextInputType.text,
        'field_type': 'address',
      },
      {
        'label': 'Enter your Phone Number',
        'instruction': 'Please enter your phone number for emergency contact.',
        'hint': 'Your phone number',
        'controller': null,
        'keyboardType': TextInputType.phone,
        'field_type': 'phone',
      },
      {
        'label': 'Emergency Contact Number',
        'instruction': 'Please enter your emergency contact number using the keyboard.',
        'hint': 'Emergency contact number',
        'controller': null,
        'keyboardType': TextInputType.phone,
        'field_type': 'emergency_contact',
      },
      {
        'label': 'Preferred Language',
        'instruction': 'Please enter your preferred language using the keyboard.',
        'hint': 'Your preferred language',
        'controller': null,
        'keyboardType': TextInputType.text,
        'field_type': 'language',
      },
    ],
  };

  @override
  void initState() {
    super.initState();
    if (supportsVoice) {
      _initializeTts();
      _initializeSpeech();
    }
    _setupControllers();
  }

 void _setupControllers() {
  // Assign controllers based on disability type
  final fields = fieldData[widget.selectedDisability]!;
  
  if (widget.selectedDisability == 'Cognitive Disability') {
    fields[0]['controller'] = nameController;
    fields[1]['controller'] = emailController;
    fields[2]['controller'] = addressController;
    fields[3]['controller'] = phoneController;
  } else if (widget.selectedDisability == 'Vision Disability' || 
             widget.selectedDisability == 'Physical Disability') {
    fields[0]['controller'] = nameController;
    fields[1]['controller'] = emergencyContactController;
    fields[2]['controller'] = languageController;
  } else {
    // For Hearing and Speech Disability
    fields[0]['controller'] = nameController;
    fields[1]['controller'] = emailController;
    fields[2]['controller'] = addressController;
    fields[3]['controller'] = phoneController;
    fields[4]['controller'] = emergencyContactController;
    fields[5]['controller'] = languageController;
  }
}

  void _initializeTts() async {
    flutterTts = FlutterTts();
    
    // Configure TTS settings
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.setVolume(0.8);
    await flutterTts.setPitch(1.0);
    
    // Set up completion handler
    flutterTts.setCompletionHandler(() {
      print('TTS completed');
    });
    
    // Give initial instructions first, then start form
    Future.delayed(Duration(milliseconds: 500), () {
      _giveInitialInstructions();
    });
  }

  void _giveInitialInstructions() async {
    if (!supportsVoice || hasGivenInitialInstructions) return;
    
    String instructions = """
    Welcome to the profile setup form. Here are the instructions:
    
    You can complete this form by speaking or typing your answers.
    
    Voice commands you can use:
    - Say "next" to move to the next field
    - Say "back" or "previous" to go to the previous field  
    - Say "repeat" to hear the current field again
    - Say "submit" when you reach the last field to save your profile
    
    For each field, you can speak your answer directly, or spell it out letter by letter.
    
  
    
    Let's begin with the first field.
    """;
    
    await flutterTts.speak(instructions);
    hasGivenInitialInstructions = true;
    
    // Start with the first field after instructions
    Future.delayed(Duration(milliseconds: 8000), () {
      _speakCurrentField();
    });
  }

  void _initializeSpeech() async {
    speech = stt.SpeechToText();
    speechEnabled = await speech.initialize();
    setState(() {});
  }

  void _speakCurrentField() async {
    if (!supportsVoice) return;
    
    final fields = fieldData[widget.selectedDisability]!;
    if (currentFieldIndex < fields.length) {
      final currentField = fields[currentFieldIndex];
      String textToSpeak = "${currentField['label']}. ${currentField['instruction']}";
      
      // Add the standard navigation instruction to each field
      if (hasGivenInitialInstructions) {
        textToSpeak += " Say next to continue, back to go previous, or repeat to hear this field again.";
      }
      
      // Reset prompt count when speaking a new field
      _promptCount = 0;
      
      // Use callback to ensure TTS completes before starting listening
      if (hasGivenInitialInstructions) {
        _speakTextWithCallback(textToSpeak, () {
          Future.delayed(Duration(milliseconds: 1000), () {
            if (speechEnabled && !isListening) {
              _startListening();
            }
          });
        });
      } else {
        await flutterTts.speak(textToSpeak);
      }
    }
  }

  void _speakText(String text) async {
    if (!supportsVoice) return;
    await flutterTts.speak(text);
  }

  // Helper method for TTS with completion callback
  void _speakTextWithCallback(String text, VoidCallback onComplete) async {
    if (!supportsVoice) return;
    
    // Set up completion handler
    flutterTts.setCompletionHandler(() {
      onComplete();
    });
    
    await flutterTts.speak(text);
  }

  void _startListening() async {
    if (!supportsVoice || !speechEnabled || isListening) return;
    
    // Clear any existing timers
    _clearTimers();
    
    bool available = await speech.initialize();
    if (available) {
      setState(() => isListening = true);
      _lastInputTime = DateTime.now();
      
      // Start listening timer for automatic restart
      _listeningTimer = Timer(Duration(seconds: listeningDuration), () {
        if (isListening) {
          _handleListeningTimeout();
        }
      });
      
      // Start inactivity timer
      _startInactivityTimer();
      
      speech.listen(
        onResult: (val) => setState(() {
          lastWords = val.recognizedWords.toLowerCase();
          print('Recognized: $lastWords'); // Debug print
          
          // Update last input time when we get results
          _lastInputTime = DateTime.now();
          _restartInactivityTimer();
          
          if (val.finalResult) {
            _processVoiceCommand(lastWords);
          }
        }),
        listenFor: Duration(seconds: listeningDuration),
        pauseFor: Duration(seconds: 3),
        partialResults: true,
        localeId: "en_US",
        onSoundLevelChange: (level) {
          print('Sound level: $level');
          // Reset inactivity timer on sound detection
          if (level > 0.1) {
            _lastInputTime = DateTime.now();
            _restartInactivityTimer();
          }
        },
      );
    }
  }

  void _startInactivityTimer() {
    _inactivityTimer = Timer(Duration(seconds: inactivityTimeout), () {
      if (isListening && _lastInputTime != null) {
        final timeSinceLastInput = DateTime.now().difference(_lastInputTime!).inSeconds;
        if (timeSinceLastInput >= inactivityTimeout) {
          _handleInactivityTimeout();
        }
      }
    });
  }

  void _restartInactivityTimer() {
    _inactivityTimer?.cancel();
    _startInactivityTimer();
  }

  void _handleListeningTimeout() {
    print('Listening timeout - no input received');
    _stopListening();
    _promptUserToSpeak();
  }

  void _handleInactivityTimeout() {
    print('Inactivity timeout - no speech detected');
    _stopListening();
    _promptUserToSpeak();
  }

  void _promptUserToSpeak() {
    if (_promptCount < maxPrompts) {
      _promptCount++;
      
      String promptMessage;
      if (isWaitingForNavigationCommand) {
        promptMessage = "Please say a command like 'next', 'back', 'repeat', or 'submit'. I'm listening again.";
      } else {
        promptMessage = "Please speak your answer or say 'next', 'back', or 'repeat'. I'm listening again.";
      }
      
      // Wait for TTS to complete before starting to listen
      _speakTextWithCallback(promptMessage, () {
        // Start listening after TTS completes
        Future.delayed(Duration(milliseconds: 1000), () {
          if (speechEnabled && !isListening) {
            _startListening();
          }
        });
      });
    } else {
      // Max prompts reached, give final instruction
      _speakText("Maximum prompts reached. Please use the buttons below or restart voice input manually.");
      _promptCount = 0; // Reset for next field
    }
  }

  void _stopListening() async {
    if (isListening) {
      await speech.stop();
      setState(() => isListening = false);
      _clearTimers();
    }
  }

  void _clearTimers() {
    _listeningTimer?.cancel();
    _inactivityTimer?.cancel();
    _listeningTimer = null;
    _inactivityTimer = null;
  }

  void _processVoiceCommand(String command) {
    print('Processing command: $command'); // Debug print
    
    // First, stop current listening
    _stopListening();
    
    // Check for navigation commands first
    if (_isNavigationCommand(command)) {
      _handleNavigationCommand(command);
      return;
    }
    
    // If not a navigation command, treat as field input
    if (isWaitingForNavigationCommand) {
      _speakText("I didn't understand that command. Please say next, back, repeat, or submit.");
      _restartListening();
    } else {
      _processFieldInput(command);
    }
  }

  bool _isNavigationCommand(String command) {
    return command.contains('next') || 
           command.contains('back') || 
           command.contains('previous') || 
           command.contains('repeat') || 
           command.contains('submit');
  }

  void _handleNavigationCommand(String command) {
    // Reset prompt count when navigation command is received
    _promptCount = 0;
    
    if (command.contains('next')) {
      _nextField();
    } else if (command.contains('back') || command.contains('previous')) {
      _previousField();
    } else if (command.contains('repeat')) {
      _speakCurrentField();
    } else if (command.contains('submit')) {
      _submitForm();
    }
    
    // Reset navigation waiting state
    setState(() => isWaitingForNavigationCommand = false);
  }

  void _processFieldInput(String input) {
    final fields = fieldData[widget.selectedDisability]!;
    if (currentFieldIndex < fields.length) {
      final controller = fields[currentFieldIndex]['controller'] as TextEditingController;
      
      // Check if input is letter by letter (contains spaces between single characters)
      List<String> words = input.split(' ');
      bool isLetterByLetter = words.every((word) => word.length <= 2) && words.length > 1;
      
      if (isLetterByLetter) {
        // Remove spaces and join letters
        String processedInput = words.join('');
        controller.text = processedInput;
        _speakText("You entered: $processedInput. Say next to continue, back to go previous, or repeat to hear this field again.");
        setState(() => isWaitingForNavigationCommand = true);
        
        // Start listening for navigation command
        _restartListening();
      } else {
        // Regular input
        controller.text = input;
        _speakText("You said: $input. Say next to continue, back to go previous, or keep speaking to add more text.");
        
        // Continue listening for more input or navigation
        _restartListening();
      }
    }
  }

  void _restartListening() {
    Future.delayed(Duration(milliseconds: 1500), () {
      if (speechEnabled && !isListening) {
        _startListening();
      }
    });
  }

  void _nextField() {
    final fields = fieldData[widget.selectedDisability]!;
    if (currentFieldIndex < fields.length - 1) {
      setState(() => currentFieldIndex++);
      if (supportsVoice) {
        _speakCurrentField();
      }
    } else {
      if (supportsVoice) {
        _speakText("This is the last field. Say submit to save your profile.");
        _restartListening();
      }
    }
  }

  void _previousField() {
    if (currentFieldIndex > 0) {
      setState(() => currentFieldIndex--);
      if (supportsVoice) {
        _speakCurrentField();
      }
    } else {
      if (supportsVoice) {
        _speakText("This is the first field. Say next to continue or repeat to hear this field again.");
        _restartListening();
      }
    }
  }

  Widget _buildStepForm() {
    final fields = fieldData[widget.selectedDisability]!;
    final currentField = fields[currentFieldIndex];
    
    return Column(
      children: [
        // Progress indicator
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            children: [
              Text(
                'Field ${currentFieldIndex + 1} of ${fields.length}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.blue.shade700,
                ),
              ),
              SizedBox(height: 8),
              LinearProgressIndicator(
                value: (currentFieldIndex + 1) / fields.length,
                backgroundColor: Colors.blue.shade100,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
              ),
            ],
          ),
        ),
        
        SizedBox(height: 30),
        
        // Current field
        _buildAccessibleField(currentField),
        
        // Show initial instructions status
        if (supportsVoice && !hasGivenInitialInstructions)
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline, color: Colors.green.shade600),
                SizedBox(width: 8),
                Text(
                  'Please listen to the initial instructions...',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        
        SizedBox(height: 30),
        
        // Voice status indicator (only for voice-enabled disabilities)
        if (supportsVoice && isListening && hasGivenInitialInstructions)
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.mic, color: Colors.red.shade600),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isWaitingForNavigationCommand 
                          ? 'Listening for navigation command...'
                          : 'Listening... Speak now or say "next", "back", or "repeat"',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                if (_promptCount > 0) ...[
                  SizedBox(height: 8),
                  Text(
                    'Prompt ${_promptCount}/$maxPrompts',
                    style: TextStyle(
                      color: Colors.red.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        
        SizedBox(height: 20),
        
        // Show last recognized words for debugging
        if (supportsVoice && lastWords.isNotEmpty)
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Last heard: "$lastWords"',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        
        SizedBox(height: 20),
        
        // Navigation buttons
        _buildNavigationButtons(fields),
      ],
    );
  }

  Widget _buildNavigationButtons(List<Map<String, dynamic>> fields) {
    List<Widget> buttons = [];
    
    // Voice control buttons (only for voice-enabled disabilities)
    if (supportsVoice && hasGivenInitialInstructions) {
      buttons.addAll([
        ElevatedButton.icon(
          onPressed: isListening ? _stopListening : _startListening,
          icon: Icon(isListening ? Icons.mic_off : Icons.mic),
          label: Text(isListening ? 'Stop' : 'Listen'),
          style: ElevatedButton.styleFrom(
            backgroundColor: isListening ? Colors.red.shade100 : Colors.green.shade100,
            foregroundColor: isListening ? Colors.red.shade800 : Colors.green.shade800,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () {
            if (!hasGivenInitialInstructions) {
              _giveInitialInstructions();
            } else {
              _speakCurrentField();
            }
          },
          icon: Icon(Icons.volume_up),
          label: Text(!hasGivenInitialInstructions ? 'Start' : 'Repeat'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.shade100,
            foregroundColor: Colors.orange.shade800,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ]);
    }
    
    // Navigation buttons (for all disabilities)
    if (currentFieldIndex > 0) {
      buttons.add(
        ElevatedButton.icon(
          onPressed: _previousField,
          icon: Icon(Icons.arrow_back),
          label: Text('Previous'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey.shade100,
            foregroundColor: Colors.grey.shade800,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      );
    }
    
      buttons.add(
        ElevatedButton.icon(
          onPressed: () {
            if (currentFieldIndex < fields.length - 1) {
              _nextField();
            } else {
              _submitForm();
            }
          },
          icon: Icon(currentFieldIndex < fields.length - 1 ? Icons.arrow_forward : Icons.check),
          label: Text(currentFieldIndex < fields.length - 1 ? 'Next' : 'Submit'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade100,
            foregroundColor: Colors.blue.shade800,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      );
    
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: buttons,
    );
  }

  Widget _buildAccessibleField(Map<String, dynamic> fieldData) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit, color: Colors.blue.shade600, size: 24),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  fieldData['label'],
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade800,
                  ),
                ),
              ),
              if (supportsVoice)
                IconButton(
                  onPressed: () => _speakText(fieldData['label']),
                  icon: Icon(Icons.volume_up, color: Colors.blue.shade600),
                  tooltip: 'Read field name aloud',
                ),
            ],
          ),
          
          SizedBox(height: 12),
          
          Text(
            fieldData['instruction'],
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
          ),
          
          SizedBox(height: 16),
          
          TextFormField(
            controller: fieldData['controller'],
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.blue.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
              ),
              hintText: fieldData['hint'],
              hintStyle: TextStyle(color: Colors.grey.shade500),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              suffixIcon: supportsVoice ? IconButton(
                onPressed: () => _speakText(fieldData['instruction']),
                icon: Icon(Icons.help_outline, color: Colors.blue.shade600),
                tooltip: 'Read instructions aloud',
              ) : null,
            ),
            keyboardType: fieldData['keyboardType'],
            style: TextStyle(fontSize: 16),
            onChanged: (value) {
              // Reset prompt count when user types
              if (supportsVoice) {
                _promptCount = 0;
              }
            },
          ),
        ],
      ),
    );
  }

  void _submitForm() async {
  final formIntegration = ProfileFormIntegration();
  
  await formIntegration.submitFormToFirestore(
    disabilityType: widget.selectedDisability,
    nameController: nameController,
    emailController: emailController,
    addressController: addressController,
    phoneController: phoneController,
    emergencyContactController: emergencyContactController,
    languageController: languageController,
    context: context,
    flutterTts: supportsVoice ? flutterTts : null,
    supportsVoice: supportsVoice,
  );
}

  @override
  void dispose() {
    _clearTimers();
    nameController.dispose();
    emergencyContactController.dispose();
    languageController.dispose();
    emailController.dispose();
    addressController.dispose();
    phoneController.dispose();
    if (supportsVoice) {
      flutterTts.stop();
      speech.stop();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Setup Profile - ${widget.selectedDisability}"),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.blue.shade100,
        actions: supportsVoice ? [
          IconButton(
            onPressed: () {
              if (!hasGivenInitialInstructions) {
                _speakText("Profile setup form. I will give you complete instructions before we begin.");
              } else {
                _speakText("Profile setup form. Complete each field to create your profile. You can speak your answers or type them.");
              }
            },
            icon: Icon(Icons.volume_up),
            tooltip: 'Read page description',
          ),
        ] : null,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: _buildStepForm(),
          ),
        ),
      ),
    );
  }
}