import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  runApp(const MaterialApp(home: HostedCheckoutPreview()));
}

class HostedCheckoutPreview extends StatelessWidget {
  const HostedCheckoutPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout Preview'),
        backgroundColor: Colors.deepPurple,
      ),
      body: const HostedCheckoutPage(
        payUrl: 'https://your-woocommerce-site.com/checkout', // Replace with your URL
        orderDocId: 'test_order_123',
      ),
    );
  }
}

class HostedCheckoutPage extends StatefulWidget {
  const HostedCheckoutPage({
    super.key,
    required this.payUrl,
    required this.orderDocId,
  });

  final String payUrl;
  final String orderDocId;

  @override
  State<HostedCheckoutPage> createState() => _HostedCheckoutPageState();
}

class _HostedCheckoutPageState extends State<HostedCheckoutPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  double _progress = 0;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setUserAgent(
        Platform.isAndroid
            ? 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/113 Mobile Safari/537.36'
            : 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            setState(() {
              _progress = progress / 100;
            });
          },
          onPageStarted: (url) {
            setState(() => _isLoading = true);
          },
          onPageFinished: (url) async {
            setState(() => _isLoading = false);
            await _applyMobileFixes();
            // Second pass after a short delay to catch any dynamic content
            await Future.delayed(const Duration(milliseconds: 800));
            await _applyMobileFixes();

            if (_isSuccessUrl(url) && mounted) {
              Navigator.of(context).pop(true);
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.payUrl));
  }

  bool _isSuccessUrl(String url) {
    final u = Uri.tryParse(url);
    return url.contains('/order-received/') ||
        (u?.queryParameters['result'] == 'success') ||
        (url.contains('key=wc_order') && url.contains('pay_for_order=false'));
  }

  Future<void> _applyMobileFixes() async {
    const js = r"""
(function() {
  try {
    // 1. Ensure proper viewport
    let viewport = document.querySelector('meta[name="viewport"]');
    if (!viewport) {
      viewport = document.createElement('meta');
      viewport.name = 'viewport';
      viewport.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
      document.head.appendChild(viewport);
    } else {
      viewport.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
    }

    // 2. Remove problematic elements
    const elementsToHide = [
      'header', 'footer', '.site-header', '.site-footer',
      '#masthead', '#colophon', '.page-header',
      '.woocommerce-breadcrumb', '.breadcrumb',
      '#cookie-law-info-bar', '.cookie-notice-container',
      '.widget-area', '.sidebar'
    ];
    
    elementsToHide.forEach(selector => {
      document.querySelectorAll(selector).forEach(el => {
        el.style.display = 'none';
      });
    });

    // 3. Make containers full width
    const containers = [
      '.container', '.woocommerce', '.woocommerce-checkout',
      '.entry-content', '.main-content', '#main',
      '.content-area', '#primary', '.site-main'
    ];
    
    containers.forEach(selector => {
      document.querySelectorAll(selector).forEach(el => {
        el.style.maxWidth = '100%';
        el.style.padding = '0 12px';
        el.style.margin = '0';
        el.style.boxSizing = 'border-box';
      });
    });

    // 4. Specifically target checkout elements
    const checkoutContainers = [
      '.col2-set', '.col-1', '.col-2', 
      '#customer_details', '#order_review',
      '.woocommerce-checkout-review-order',
      '.woocommerce-billing-fields',
      '.woocommerce-additional-fields',
      '.woocommerce-checkout-payment'
    ];
    
    checkoutContainers.forEach(selector => {
      document.querySelectorAll(selector).forEach(el => {
        el.style.width = '100%';
        el.style.float = 'none';
        el.style.margin = '0';
        el.style.padding = '0';
        el.style.boxSizing = 'border-box';
      });
    });

    // 5. Fix tables specifically
    document.querySelectorAll('table.shop_table').forEach(table => {
      table.style.width = '100%';
      table.style.tableLayout = 'fixed';
      table.style.fontSize = '14px';
    });

    document.querySelectorAll('table.shop_table th, table.shop_table td').forEach(cell => {
      cell.style.padding = '8px 5px';
      cell.style.wordBreak = 'break-word';
    });

    // 6. Fix quantity dropdown specifically
    document.querySelectorAll('.quantity input, .quantity select').forEach(input => {
      input.style.width = '70px';
      input.style.height = '40px';
      input.style.padding = '5px';
      input.style.margin = '0 5px 0 0';
    });

    document.querySelectorAll('.quantity').forEach(qty => {
      qty.style.display = 'inline-block';
      qty.style.margin = '0 10px 0 0';
    });

    // 7. Fix buttons
    document.querySelectorAll('button, .button, input[type="submit"]').forEach(btn => {
      btn.style.height = '44px';
      btn.style.lineHeight = '44px';
      btn.style.padding = '0 20px';
      btn.style.fontSize = '16px';
    });

    // 8. Add global styles with high specificity
    const styleId = 'flutter-webview-fixes';
    if (!document.getElementById(styleId)) {
      const style = document.createElement('style');
      style.id = styleId;
      style.innerHTML = `
        body.woocommerce-checkout {
          padding: 10px !important;
          margin: 0 !important;
          font-family: -apple-system, BlinkMacSystemFont, sans-serif !important;
        }
        
        body.woocommerce-checkout .site-content {
          padding: 0 !important;
          margin: 0 !important;
          width: 100% !important;
          max-width: 100% !important;
        }
        
        /* Fix quantity dropdown alignment */
        .woocommerce-checkout .quantity {
          display: inline-block !important;
          white-space: nowrap !important;
        }
        
        .woocommerce-checkout .input-text.qty {
          display: inline-block !important;
          width: 70px !important;
          vertical-align: middle !important;
        }
        
        /* Ensure form elements are mobile-friendly */
        @media (max-width: 768px) {
          .woocommerce-checkout .col2-set .col-1,
          .woocommerce-checkout .col2-set .col-2 {
            float: none !important;
            width: 100% !important;
            padding: 0 !important;
          }
          
          .woocommerce-checkout .form-row {
            margin-bottom: 15px !important;
          }
          
          .woocommerce-checkout .woocommerce-billing-fields .form-row,
          .woocommerce-checkout .woocommerce-shipping-fields .form-row {
            width: 100% !important;
            float: none !important;
          }
        }
        
        /* Fix payment section */
        #payment {
          background: #f8f8f8 !important;
          padding: 20px !important;
          border-radius: 8px !important;
          margin-top: 20px !important;
        }
        
        /* Product listing fixes */
        .woocommerce-checkout-review-order-table td {
          vertical-align: middle !important;
        }
        
        .woocommerce-checkout-review-order-table .product-name {
          font-weight: 600 !important;
        }
      `;
      document.head.appendChild(style);
    }

    // 9. Scroll to the payment section
    const paymentSection = document.querySelector('#order_review, #payment');
    if (paymentSection) {
      paymentSection.scrollIntoView({behavior: 'smooth', block: 'start'});
    }

  } catch (e) {
    console.error('Error applying mobile fixes:', e);
  }
})();
""";

    await _controller.runJavaScript(js);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => Navigator.of(context).pop(false),
          color: Colors.white,
        ),
        title: const Text('Secure Payment', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              _controller.reload();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            LinearProgressIndicator(
              value: _progress,
              backgroundColor: Colors.grey[300],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.deepPurple),
            ),
        ],
      ),
    );
  }
}