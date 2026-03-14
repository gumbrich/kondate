import 'package:core/core.dart';
import 'package:flutter/material.dart';

class RecipeListSection extends StatelessWidget {
  final List<Recipe> recipes;
  final void Function(int index) onDelete;

  const RecipeListSection({
    super.key,
    required this.recipes,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Saved recipes (${recipes.length})',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 180,
          child: ListView.builder(
            itemCount: recipes.length,
            itemBuilder: (_, int i) {
              final Recipe r = recipes[i];

              return ListTile(
                title: Text(r.title),
                subtitle: Text(
                  r.sourceUrl.toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => onDelete(i),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
