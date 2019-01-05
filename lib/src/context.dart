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

library gltf.context;

import 'dart:collection';

import 'package:gltf/src/base/gltf_property.dart';
import 'package:gltf/src/errors.dart';
import 'package:gltf/src/ext/extensions.dart';

class ValidationOptions {
  final int maxIssues;
  final Set<String> ignoredIssues = Set<String>();
  final Map<String, Severity> severityOverrides;

  ValidationOptions(
      {int maxIssues, List<String> ignoredIssues, this.severityOverrides})
      : maxIssues = maxIssues ?? 0 {
    if (ignoredIssues != null) {
      this.ignoredIssues.addAll(ignoredIssues);
    }
  }
}

class Context {
  final bool validate;

  final ValidationOptions options;
  final List<String> path = <String>[];

  static Iterable<String> get defaultExtensionNames =>
      kDefaultExtensions.map((e) => e.name);

  Context({this.validate = true, ValidationOptions options})
      : options = options ?? ValidationOptions() {
    _extensionsLoadedView = UnmodifiableListView(_extensionsLoaded);
    _extensionsUsedView = UnmodifiableListView(_extensionsUsed);
    _extensionsFunctionsView = UnmodifiableMapView(_extensionsFunctions);
    _resourcesView = UnmodifiableListView(_resources);
  }

  final Map<Object, Object> owners = <Object, Object>{};

  final Map<Type, List<LinkableExtensionEntry>> linkableExtensions =
      <Type, List<LinkableExtensionEntry>>{};

  final Map<SafeList, List<String>> extensionCollections =
      <SafeList, List<String>>{};

  void registerObjectsOwner(Object owner, Iterable<Object> objects) {
    for (final o in objects) {
      if (o != null) {
        owners[o] = owner;
      }
    }
  }

  bool _isTruncated = false;
  bool get isTruncated => _isTruncated;

  final Map<ExtensionTuple, ExtFuncs> _extensionsFunctions =
      <ExtensionTuple, ExtFuncs>{};
  Map<ExtensionTuple, ExtFuncs> _extensionsFunctionsView;
  Map<ExtensionTuple, ExtFuncs> get extensionsFunctions =>
      _extensionsFunctionsView;

  final List<String> _extensionsUsed = <String>[];
  List<String> _extensionsUsedView;
  List<String> get extensionsUsed => _extensionsUsedView;

  final List<String> _extensionsLoaded = <String>[];
  List<String> _extensionsLoadedView;
  List<String> get extensionsLoaded => _extensionsLoadedView;

  final List<Map<String, Object>> _resources = <Map<String, Object>>[];
  List<Map<String, Object>> _resourcesView;
  List<Map<String, Object>> get resources => _resourcesView;

  final Set<Extension> _userExtensions = Set<Extension>();

  final List<Issue> _issues = <Issue>[];

  List<Issue> get issues => _issues;

  Iterable<Issue> get errors =>
      _issues.where((issue) => issue.severity == Severity.Error);

  Iterable<Issue> get warnings =>
      _issues.where((issue) => issue.severity == Severity.Warning);

  Iterable<Issue> get infos =>
      _issues.where((issue) => issue.severity == Severity.Information);

  Iterable<Issue> get hints =>
      _issues.where((issue) => issue.severity == Severity.Hint);

  final StringBuffer _sb = StringBuffer();

  String getPointerString([String token]) {
    if (path.isEmpty) {
      return token == null ? '/' : '/$token';
    }

    var i = 0;
    _sb..write('/')..write(path[0]);

    while (++i < path.length) {
      _sb..write('/')..write(path[i]);
    }

    if (token != null) {
      _sb..write('/')..write(token);
    }

    final result = _sb.toString();
    _sb.clear();
    return result;
  }

  void registerExtensions(List<Extension> userExtensions) {
    _userExtensions.addAll(userExtensions);
  }

  void initExtensions(
      List<String> extensionsUsed, List<String> extensionsRequired) {
    _extensionsUsed.addAll(extensionsUsed);

    for (var i = 0; i < extensionsUsed.length; ++i) {
      final extensionName = extensionsUsed[i];

      if (extensionName == 'VRM') {
        continue;
      }

      if (!kReservedPrefixes.any(extensionName.startsWith)) {
        addIssue(SemanticError.unreservedExtensionPrefix,
            name: '$EXTENSIONS_USED/$i', args: [extensionName.split('_')[0]]);
      }

      final extension = _userExtensions.firstWhere(
          (extension) => extension.name == extensionName,
          orElse: () => kDefaultExtensions.firstWhere(
              (extension) => extension.name == extensionName,
              orElse: () => null));

      if (extension == null) {
        addIssue(LinkError.unsupportedExtension,
            name: '$EXTENSIONS_USED/$i', args: [extensionName]);
        continue;
      }

      extension.functions?.forEach((type, funcs) {
        _extensionsFunctions[ExtensionTuple(type, extension.name)] = funcs;
      });
      _extensionsLoaded.add(extensionName);
    }

    if (validate) {
      for (var i = 0; i < extensionsRequired.length; ++i) {
        final value = extensionsRequired[i];
        if (!extensionsUsed.contains(value)) {
          addIssue(SemanticError.unusedExtensionRequired,
              name: '$EXTENSIONS_REQUIRED/$i', args: [value]);
        }
      }
    }
  }

  void addIssue(IssueType issueType,
      {String name, List<Object> args, int offset, int index}) {
    if (options.ignoredIssues.contains(issueType.code)) {
      return;
    }

    if (options.maxIssues > 0 && _issues.length == options.maxIssues) {
      _isTruncated = true;
      throw const IssuesLimitExceededException();
    }

    final severityOverride = (options.severityOverrides != null)
        ? options.severityOverrides[issueType.code]
        : null;

    if (offset != null) {
      _issues.add(Issue(issueType, args,
          offset: offset, severityOverride: severityOverride));
    } else {
      final token = index != null ? index.toString() : name;
      _issues.add(Issue(issueType, args,
          pointer: getPointerString(token),
          severityOverride: severityOverride));
    }
  }

  void addResource(Map<String, Object> info) => _resources.add(info);

  bool _isGlb = false;
  bool get isGlb => _isGlb;

  void setGlb() {
    _isGlb = true;
  }
}

class IssuesLimitExceededException implements Exception {
  const IssuesLimitExceededException();
}
