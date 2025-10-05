import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main_page.dart';

class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key});
  @override State<VerifyEmailPage> createState()=>_VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage>{
  late final User _user;
  Timer? _timer;
  bool _sending=false;
  bool _errorOccurred=false;

  @override
  void initState(){
    super.initState();
    _user = FirebaseAuth.instance.currentUser!;
    if(!_user.emailVerified){ _sendVerificationEmail(); _startEmailCheckTimer(); }
    else { WidgetsBinding.instance.addPostFrameCallback((_){
      Navigator.pushReplacement(context, MaterialPageRoute(builder:(_)=>const MainPage()));
    });}
  }

  Future<void> _sendVerificationEmail() async{
    try{ setState(()=>_sending=true); await _user.sendEmailVerification(); _errorOccurred=false;
    }catch(e){ debugPrint('Error sending email: $e'); if(mounted) setState(()=>_errorOccurred=true);
    }finally{ if(mounted) setState(()=>_sending=false); }
  }

  void _startEmailCheckTimer(){
    _timer = Timer.periodic(const Duration(seconds:3), (_) async{
      try{
        await _user.reload();
        final u = FirebaseAuth.instance.currentUser;
        if(u!=null && u.emailVerified){
          _timer?.cancel();
          await FirebaseFirestore.instance.collection('users').doc(u.uid)
              .set({'emailVerifiedAt': Timestamp.now()}, SetOptions(merge:true));
          if(mounted){ Navigator.pushReplacement(context, MaterialPageRoute(builder:(_)=>const MainPage())); }
        }
      }catch(e){ debugPrint('Timer check error: $e'); }
    });
  }

  @override void dispose(){ _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context){
    return Scaffold(
      body: Stack(fit: StackFit.expand, children:[
        Image.asset('assets/background/fade_base.jpg', fit: BoxFit.cover),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX:8, sigmaY:8),
          child: Container(
            color: Colors.black.withOpacity(0.2),
            padding: const EdgeInsets.symmetric(horizontal:24, vertical:60),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children:[
              const Icon(Icons.email_outlined, size:80, color: Colors.white),
              const SizedBox(height:20),
              const Text('Verify Your Email',
                  style: TextStyle(fontSize:26, color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height:12),
              Text("We sent a verification link to ${_user.email}. Once you tap it, this screen continues automatically.",
                  textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height:24),
              ElevatedButton.icon(
                onPressed: _sending?null:_sendVerificationEmail,
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: _sending
                    ? const SizedBox(height:20,width:20,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white))
                    : const Text("Resend Email", style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(horizontal:24, vertical:14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
              const SizedBox(height:12),
              TextButton(onPressed: () async{ await _user.reload(); }, child: const Text("I’ve verified already")),
              TextButton(onPressed: () async{ await FirebaseAuth.instance.signOut(); }, child: const Text("Use a different email")),
              if(_errorOccurred) const Padding(
                padding: EdgeInsets.only(top:16),
                child: Text("Could not send email. Please try again.",
                    style: TextStyle(color: Colors.redAccent), textAlign: TextAlign.center),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
