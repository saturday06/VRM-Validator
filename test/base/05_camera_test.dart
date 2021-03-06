/*
 * # Copyright (c) 2016-2017 The Khronos Group Inc.
 * # Copyright (c) 2016 Alexey Knyazev
 * #
 * # Licensed under the Apache License, Version 2.0 (the "License");
 * # you may not use this file except in compliance with the License.
 * # You may obtain a copy of the License at
 * #
 * #     http://www.apache.org/licenses/LICENSE-2.0
 * #
 * # Unless required by applicable law or agreed to in writing, software
 * # distributed under the License is distributed on an "AS IS" BASIS,
 * # WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * # See the License for the specific language governing permissions and
 * # limitations under the License.
 */

import 'dart:io';

import 'package:test/test.dart';
import 'package:gltf/gltf.dart';
import 'package:gltf/src/errors.dart';

import '../utils.dart';

void main() {
  group('Camera', () {
    test('Empty array', () async {
      final reader =
          GltfJsonReader(File('test/base/data/camera/empty.gltf').openRead());

      final context = Context()
        ..path.add('cameras')
        ..addIssue(SchemaError.emptyEntity);

      await reader.read();

      expect(reader.context.issues, unorderedMatches(context.issues));
    });

    test('Empty object & empty nested objects', () async {
      final reader = GltfJsonReader(
          File('test/base/data/camera/empty_object.gltf').openRead(),
          ignoreUnusedContext);

      final context = Context()
        ..path.add('cameras')
        ..path.add('0')
        ..addIssue(SchemaError.undefinedProperty, args: ['type'])
        ..path.removeLast()
        ..path.add('1')
        ..addIssue(SchemaError.undefinedProperty, args: ['perspective'])
        ..path.removeLast()
        ..path.add('2')
        ..path.add('perspective')
        ..addIssue(SchemaError.undefinedProperty, args: ['znear'])
        ..addIssue(SchemaError.undefinedProperty, args: ['yfov'])
        ..path.removeLast()
        ..path.removeLast()
        ..path.add('3')
        ..path.add('orthographic')
        ..addIssue(SchemaError.undefinedProperty, args: ['zfar'])
        ..addIssue(SchemaError.undefinedProperty, args: ['znear'])
        ..addIssue(SchemaError.undefinedProperty, args: ['xmag'])
        ..addIssue(SchemaError.undefinedProperty, args: ['ymag'])
        ..path.removeLast()
        ..path.removeLast()
        ..path.add('4')
        ..addIssue(SchemaError.valueNotInList, name: 'type', args: [
          'unknown',
          ['orthographic', 'perspective']
        ]);

      await reader.read();

      expect(reader.context.issues, unorderedMatches(context.issues));
    });

    test('Custom Property', () async {
      final reader = GltfJsonReader(
          File('test/base/data/camera/custom_property.gltf').openRead(),
          ignoreUnusedContext);

      final context = Context()
        ..path.add('cameras')
        ..path.add('0')
        ..addIssue(SchemaError.unexpectedProperty, name: 'customProperty')
        ..path.add('perspective')
        ..addIssue(SchemaError.unexpectedProperty, name: 'customProperty')
        ..path.removeLast()
        ..path.removeLast()
        ..path.add('1')
        ..path.add('orthographic')
        ..addIssue(SchemaError.unexpectedProperty, name: 'customProperty');

      await reader.read();

      expect(reader.context.issues, unorderedMatches(context.issues));
    });

    test('Valid', () async {
      final reader = GltfJsonReader(
          File('test/base/data/camera/valid_full.gltf').openRead(),
          ignoreUnusedContext);

      final result = await reader.read();

      expect(reader.context.issues, isEmpty);

      expect(
          result.gltf.cameras.toString(),
          //ignore: lines_longer_than_80_chars
          '[{type: perspective, perspective: {aspectRatio: 1.0, yfov: 1.0, zfar: 10.0, znear: 1.0, extensions: {}}, extensions: {}}, {type: orthographic, orthographic: {xmag: 1.0, ymag: 1.0, zfar: 10.0, znear: 1.0, extensions: {}}, extensions: {}}]');
    });

    test('Z Far / Z Near, ambigous type', () async {
      final reader = GltfJsonReader(
          File('test/base/data/camera/invalid_cameras.gltf').openRead(),
          ignoreUnusedContext);

      final context = Context()
        ..path.add('cameras')
        ..path.add('0')
        ..addIssue(SchemaError.oneOfMismatch,
            args: ['orthographic', 'perspective'])
        ..path.add('perspective')
        ..addIssue(SemanticError.cameraZfarLequalZnear)
        ..path.removeLast()
        ..path.removeLast()
        ..path.add('1')
        ..path.add('orthographic')
        ..addIssue(SemanticError.cameraZfarLequalZnear)
        ..path.removeLast()
        ..path.removeLast()
        ..path.add('2')
        ..path.add('orthographic')
        ..addIssue(SemanticError.cameraXmagYmagZero)
        ..path.removeLast()
        ..path.removeLast()
        ..path.add('3')
        ..path.add('orthographic')
        ..addIssue(SemanticError.cameraXmagYmagZero);

      await reader.read();

      expect(reader.context.issues, unorderedMatches(context.issues));
    });
  });
}
