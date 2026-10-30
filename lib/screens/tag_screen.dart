import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/expense_provider.dart';
import '../models/tag.dart';

class TagScreen extends StatefulWidget {
  const TagScreen({Key? key}) : super(key: key);

  @override
  State<TagScreen> createState() => _TagScreenState();
}

class _TagScreenState extends State<TagScreen> {
  void _showTagDialog([Tag? tag]) {
    final nameController = TextEditingController(text: tag?.name ?? '');
    final colorController = TextEditingController(text: tag?.color ?? '0xFF2196F3');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(tag == null ? 'Tambah Tag' : 'Edit Tag'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nama Tag'),
              ),
              TextField(
                controller: colorController,
                decoration: const InputDecoration(labelText: 'Warna (Format: 0xFF...)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
            TextButton(
              onPressed: () {
                final provider = Provider.of<ExpenseProvider>(context, listen: false);
                final newTag = Tag(
                  id: tag?.id,
                  name: nameController.text,
                  color: colorController.text,
                );
                if (tag == null) {
                  provider.addTag(newTag);
                } else {
                  provider.updateTag(newTag);
                }
                Navigator.pop(context);
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tags'),
      ),
      body: Consumer<ExpenseProvider>(
        builder: (context, provider, child) {
          final tags = provider.tags;
          return ListView.builder(
            itemCount: tags.length,
            itemBuilder: (context, index) {
              final tag = tags[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Color(int.parse(tag.color)).withOpacity(0.2),
                  child: Icon(Icons.label, color: Color(int.parse(tag.color))),
                ),
                title: Text(tag.name),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showTagDialog(tag),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        provider.deleteTag(tag.id!);
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTagDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
