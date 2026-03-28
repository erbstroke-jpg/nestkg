import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nestkg/l10n/generated/app_localizations.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../services/api_client.dart';
import '../widgets/widgets.dart';

// ── Conversations List ────────────────────────────

class ConversationsScreen extends ConsumerWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;
    final convsAsync = ref.watch(conversationsProvider);
    final myId = ref.watch(authProvider).user?.id ?? 0;

    return Scaffold(
      appBar: AppBar(title: Text(loc.messages)),
      body: convsAsync.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => AppErrorWidget(message: e.toString(), onRetry: () => ref.invalidate(conversationsProvider)),
        data: (result) {
          if (result.items.isEmpty) return EmptyState(text: loc.noMessages, icon: Icons.chat_bubble_outline);
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(conversationsProvider),
            child: ListView.builder(
              itemCount: result.items.length,
              itemBuilder: (_, i) {
                final conv = result.items[i];
                final other = conv.otherParticipant(myId);
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: other.profileImageUrl != null
                        ? CachedNetworkImageProvider(mediaUrl(other.profileImageUrl!)) : null,
                    child: other.profileImageUrl == null ? Text(other.fullName.isNotEmpty ? other.fullName[0] : '?') : null,
                  ),
                  title: Text(other.fullName, style: TextStyle(
                    fontWeight: conv.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                  )),
                  subtitle: Text(conv.lastMessagePreview ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: conv.unreadCount > 0 ? FontWeight.w600 : FontWeight.normal)),
                  trailing: conv.unreadCount > 0 ? Badge(label: Text('${conv.unreadCount}')) : null,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ChatScreen(conversation: conv, myId: myId),
                    )).then((_) => ref.invalidate(conversationsProvider));
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// ── Chat Screen ───────────────────────────────────

class ChatScreen extends ConsumerStatefulWidget {
  final Conversation conversation;
  final int myId;
  const ChatScreen({super.key, required this.conversation, required this.myId});
  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  List<Message> _messages = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() { super.initState(); _loadMessages(); }
  @override
  void dispose() { _textController.dispose(); _scrollController.dispose(); super.dispose(); }

  Future<void> _loadMessages() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await ref.read(messagingServiceProvider).getMessages(widget.conversation.id);
      // Backend returns desc order, sort ascending for chat display
      final msgs = result.items.toList();
      msgs.sort((a, b) => a.sentAt.compareTo(b.sentAt));
      setState(() { _messages = msgs; _loading = false; });
      _scrollToBottom();
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    _textController.clear();
    try {
      final msg = await ref.read(messagingServiceProvider).sendMessage(widget.conversation.id, text);
      setState(() => _messages.add(msg));
      _scrollToBottom();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
    setState(() => _sending = false);
  }

  Future<void> _sendAttachment() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;

    setState(() => _sending = true);
    try {
      final bytes = await picked.readAsBytes();
      final msg = await ref.read(messagingServiceProvider).sendMessageWithAttachmentBytes(
        widget.conversation.id, bytes, picked.name,
        textBody: _textController.text.trim().isEmpty ? null : _textController.text.trim(),
      );
      _textController.clear();
      setState(() => _messages.add(msg));
      _scrollToBottom();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
    setState(() => _sending = false);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final other = widget.conversation.otherParticipant(widget.myId);

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          CircleAvatar(radius: 16,
            backgroundImage: other.profileImageUrl != null ? CachedNetworkImageProvider(mediaUrl(other.profileImageUrl!)) : null,
            child: other.profileImageUrl == null ? Text(other.fullName.isNotEmpty ? other.fullName[0] : '?', style: const TextStyle(fontSize: 12)) : null),
          const SizedBox(width: 10),
          Expanded(child: Text(other.fullName, style: const TextStyle(fontSize: 16), overflow: TextOverflow.ellipsis)),
        ]),
      ),
      body: Column(children: [
        Expanded(
          child: _loading ? const LoadingWidget()
              : _error != null ? AppErrorWidget(message: _error!, onRetry: _loadMessages)
              : _messages.isEmpty
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey[300]),
                    const SizedBox(height: 12),
                    Text(loc.typeMessage, style: TextStyle(color: Colors.grey[500])),
                  ]))
                : ListView.builder(
                    controller: _scrollController, padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) => _MessageBubble(message: _messages[i], isMe: _messages[i].senderId == widget.myId)),
        ),
        SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor,
              border: Border(top: BorderSide(color: Colors.grey[300]!))),
            child: Row(children: [
              IconButton(icon: const Icon(Icons.attach_file), onPressed: _sending ? null : _sendAttachment),
              Expanded(child: TextField(controller: _textController,
                decoration: InputDecoration(hintText: loc.typeMessage, border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
                textInputAction: TextInputAction.send, onSubmitted: (_) => _send())),
              const SizedBox(width: 4),
              IconButton.filled(onPressed: _sending ? null : _send,
                icon: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send)),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final time = message.sentAt.contains('T') ? message.sentAt.split('T')[1].substring(0, 5) : '';
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isMe ? Theme.of(context).colorScheme.primary.withOpacity(0.1) : Colors.grey[100],
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isMe ? const Radius.circular(4) : null,
            bottomLeft: !isMe ? const Radius.circular(4) : null)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (final att in message.attachments)
            Padding(padding: const EdgeInsets.only(bottom: 6),
              child: att.isImage
                  ? ClipRRect(borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(imageUrl: mediaUrl(att.fileUrl), width: 200,
                        placeholder: (_, __) => const SizedBox(width: 200, height: 120, child: Center(child: CircularProgressIndicator())),
                        errorWidget: (_, __, ___) => const Icon(Icons.broken_image)))
                  : Container(padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.insert_drive_file, size: 20), const SizedBox(width: 6),
                        Flexible(child: Text(att.originalName, overflow: TextOverflow.ellipsis))]))),
          if (message.textBody != null && message.textBody!.isNotEmpty)
            Text(message.textBody!, style: const TextStyle(fontSize: 15)),
          const SizedBox(height: 2),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text(time, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
            if (isMe) ...[
              const SizedBox(width: 4),
              Icon(message.isRead ? Icons.done_all : Icons.done, size: 14,
                color: message.isRead ? Colors.blue : Colors.grey[400]),
            ],
          ]),
        ]),
      ),
    );
  }
}
