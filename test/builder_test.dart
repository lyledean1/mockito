// Copyright 2019 Dart Mockito authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

@TestOn('vm')
import 'package:build/build.dart';
import 'package:build/experiments.dart';
import 'package:build_test/build_test.dart';
import 'package:meta/meta.dart';
import 'package:mockito/src/builder.dart';
import 'package:package_config/package_config.dart';
import 'package:test/test.dart';

Builder buildMocks(BuilderOptions options) => MockBuilder();

const annotationsAsset = {
  'mockito|lib/annotations.dart': '''
class GenerateMocks {
  final List<Type> classes;

  const GenerateMocks(this.classes);
}
'''
};

const simpleTestAsset = {
  'foo|test/foo_test.dart': '''
import 'package:foo/foo.dart';
import 'package:mockito/annotations.dart';
@GenerateMocks([Foo])
void main() {}
'''
};

void main() {
  test(
      'generates mock for an imported class but does not override private '
      'or static methods or methods w/ zero parameters', () async {
    await _testWithNonNullable(
      {
        ...annotationsAsset,
        ...simpleTestAsset,
        'foo|lib/foo.dart': dedent(r'''
        class Foo {
          dynamic a() => 7;
          int _b(int x) => 8;
          static int c(int y) => 9;
        }
        '''),
      },
      outputs: {
        'foo|test/foo_test.mocks.dart': dedent(r'''
        import 'package:mockito/mockito.dart' as _i1;
        import 'package:foo/foo.dart' as _i2;

        /// A class which mocks [Foo].
        ///
        /// See the documentation for Mockito's code generation for more information.
        class MockFoo extends _i1.Mock implements _i2.Foo {}
        '''),
      },
    );
  });

  test(
      'generates mock for an imported class but does not override private '
      'or static fields', () async {
    await _testWithNonNullable(
      {
        ...annotationsAsset,
        ...simpleTestAsset,
        'foo|lib/foo.dart': dedent(r'''
        class Foo {
          int _a;
          static int b;
        }
        '''),
      },
      outputs: {
        'foo|test/foo_test.mocks.dart': dedent(r'''
        import 'package:mockito/mockito.dart' as _i1;
        import 'package:foo/foo.dart' as _i2;

        /// A class which mocks [Foo].
        ///
        /// See the documentation for Mockito's code generation for more information.
        class MockFoo extends _i1.Mock implements _i2.Foo {}
        '''),
      },
    );
  });

  test(
      'generates mock for an imported class but does not override any '
      'extension methods', () async {
    await _testWithNonNullable(
      {
        ...annotationsAsset,
        ...simpleTestAsset,
        'foo|lib/foo.dart': dedent(r'''
        extension X on Foo {
          dynamic x(int m, String n) => n + 1;
        }
        class Foo {
          dynamic a(int m, String n) => n + 1;
        }
        '''),
      },
      outputs: {
        'foo|test/foo_test.mocks.dart': dedent(r'''
        import 'package:mockito/mockito.dart' as _i1;
        import 'package:foo/foo.dart' as _i2;

        /// A class which mocks [Foo].
        ///
        /// See the documentation for Mockito's code generation for more information.
        class MockFoo extends _i1.Mock implements _i2.Foo {
          dynamic a(int m, String n) =>
              super.noSuchMethod(Invocation.method(#a, [m, n]));
        }
        '''),
      },
    );
  });

  test('generates a mock class and overrides methods parameters', () async {
    await _testWithNonNullable(
      {
        ...annotationsAsset,
        ...simpleTestAsset,
        'foo|lib/foo.dart': dedent(r'''
        class Foo {
          dynamic a(int m, String n) => n + 1;
          dynamic b(List<int> list) => list.length;
          void c(String one, [String two, String three = ""]) => print('$one$two$three');
          void d(String one, {String two, String three = ""}) => print('$one$two$three');
          Future<void> e(String s) async => print(s);
          // TODO(srawlins): Figure out async*; doesn't work yet. `isGenerator`
          // does not appear to be working.
          // Stream<void> f(String s) async* => print(s);
          // Iterable<void> g(String s) sync* => print(s);
        }
        '''),
      },
      outputs: {
        'foo|test/foo_test.mocks.dart': dedent(r'''
        import 'package:mockito/mockito.dart' as _i1;
        import 'package:foo/foo.dart' as _i2;
        import 'dart:async' as _i3;

        /// A class which mocks [Foo].
        ///
        /// See the documentation for Mockito's code generation for more information.
        class MockFoo extends _i1.Mock implements _i2.Foo {
          dynamic a(int m, String n) =>
              super.noSuchMethod(Invocation.method(#a, [m, n]));
          dynamic b(List<int> list) =>
              super.noSuchMethod(Invocation.method(#b, [list]));
          void c(String one, [String two, String three = ""]) =>
              super.noSuchMethod(Invocation.method(#c, [one, two, three]));
          void d(String one, {String two, String three = ""}) => super
              .noSuchMethod(Invocation.method(#d, [one], {#two: two, #three: three}));
          _i3.Future<void> e(String s) async =>
              super.noSuchMethod(Invocation.method(#e, [s]));
        }
        '''),
      },
    );
  });

  test('generates multiple mock classes', () async {
    await _testWithNonNullable(
      {
        ...annotationsAsset,
        'foo|lib/foo.dart': dedent(r'''
        class Foo {
          dynamic a(int m, String n) => n + 1;
        }
        class Bar {
          dynamic b(List<int> list) => list.length;
        }
        '''),
        'foo|test/foo_test.dart': '''
        import 'package:foo/foo.dart';
        import 'package:mockito/annotations.dart';
        @GenerateMocks([Foo, Bar])
        void main() {}
        '''
      },
      outputs: {
        'foo|test/foo_test.mocks.dart': dedent(r'''
        import 'package:mockito/mockito.dart' as _i1;
        import 'package:foo/foo.dart' as _i2;

        /// A class which mocks [Foo].
        ///
        /// See the documentation for Mockito's code generation for more information.
        class MockFoo extends _i1.Mock implements _i2.Foo {
          dynamic a(int m, String n) =>
              super.noSuchMethod(Invocation.method(#a, [m, n]));
        }

        /// A class which mocks [Bar].
        ///
        /// See the documentation for Mockito's code generation for more information.
        class MockBar extends _i1.Mock implements _i2.Bar {
          dynamic b(List<int> list) =>
              super.noSuchMethod(Invocation.method(#b, [list]));
        }
        '''),
      },
    );
  });

  test('generates generic mock classes', () async {
    await _testWithNonNullable(
      {
        ...annotationsAsset,
        'foo|lib/foo.dart': dedent(r'''
        class Foo<T, U> {
          dynamic a(int m) => m + 1;
        }
        '''),
        'foo|test/foo_test.dart': '''
        import 'package:foo/foo.dart';
        import 'package:mockito/annotations.dart';
        @GenerateMocks([Foo])
        void main() {}
        '''
      },
      outputs: {
        'foo|test/foo_test.mocks.dart': dedent(r'''
        import 'package:mockito/mockito.dart' as _i1;
        import 'package:foo/foo.dart' as _i2;

        /// A class which mocks [Foo].
        ///
        /// See the documentation for Mockito's code generation for more information.
        class MockFoo<T, U> extends _i1.Mock implements _i2.Foo<T, U> {
          dynamic a(int m) => super.noSuchMethod(Invocation.method(#a, [m]));
        }
        '''),
      },
    );
  });

  test('generates generic mock classes with type bounds', () async {
    await _testWithNonNullable(
      {
        ...annotationsAsset,
        'foo|lib/foo.dart': dedent(r'''
        class Foo {
          dynamic a(int m) => m + 1;
        }
        class Bar<T extends Foo> {
          dynamic b(int m) => m + 1;
        }
        '''),
        'foo|test/foo_test.dart': '''
        import 'package:foo/foo.dart';
        import 'package:mockito/annotations.dart';
        @GenerateMocks([Foo, Bar])
        void main() {}
        '''
      },
      outputs: {
        'foo|test/foo_test.mocks.dart': dedent(r'''
        import 'package:mockito/mockito.dart' as _i1;
        import 'package:foo/foo.dart' as _i2;

        /// A class which mocks [Foo].
        ///
        /// See the documentation for Mockito's code generation for more information.
        class MockFoo extends _i1.Mock implements _i2.Foo {
          dynamic a(int m) => super.noSuchMethod(Invocation.method(#a, [m]));
        }

        /// A class which mocks [Bar].
        ///
        /// See the documentation for Mockito's code generation for more information.
        class MockBar<T extends _i2.Foo> extends _i1.Mock implements _i2.Bar<T> {
          dynamic b(int m) => super.noSuchMethod(Invocation.method(#b, [m]));
        }
        '''),
      },
    );
  });

  test('writes non-interface types w/o imports', () async {
    await _testWithNonNullable(
      {
        ...annotationsAsset,
        ...simpleTestAsset,
        'foo|lib/foo.dart': dedent(r'''
        class Foo<T> {
          void f(dynamic a, int b) {}
          void g(T c) {}
          void h<U>(U d) {}
        }
        '''),
      },
      outputs: {
        'foo|test/foo_test.mocks.dart': dedent(r'''
        import 'package:mockito/mockito.dart' as _i1;
        import 'package:foo/foo.dart' as _i2;

        /// A class which mocks [Foo].
        ///
        /// See the documentation for Mockito's code generation for more information.
        class MockFoo<T> extends _i1.Mock implements _i2.Foo<T> {
          void f(dynamic a, int b) => super.noSuchMethod(Invocation.method(#f, [a, b]));
          void g(T c) => super.noSuchMethod(Invocation.method(#g, [c]));
          void h<U>(U d) => super.noSuchMethod(Invocation.method(#h, [d]));
        }
        '''),
      },
    );
  });

  test('imports libraries for external class types', () async {
    await _testWithNonNullable(
      {
        ...annotationsAsset,
        ...simpleTestAsset,
        'foo|lib/foo.dart': dedent(r'''
        import 'dart:async';
        class Foo {
          dynamic f(List<Foo> list) {}
        }
        '''),
      },
      outputs: {
        'foo|test/foo_test.mocks.dart': dedent(r'''
        import 'package:mockito/mockito.dart' as _i1;
        import 'package:foo/foo.dart' as _i2;

        /// A class which mocks [Foo].
        ///
        /// See the documentation for Mockito's code generation for more information.
        class MockFoo extends _i1.Mock implements _i2.Foo {
          dynamic f(List<_i2.Foo> list) =>
              super.noSuchMethod(Invocation.method(#f, [list]));
        }
        '''),
      },
    );
  });

  test('imports libraries for type aliases with external types', () async {
    await _testWithNonNullable(
      {
        ...annotationsAsset,
        ...simpleTestAsset,
        'foo|lib/foo.dart': dedent(r'''
        import 'dart:async';
        typedef Callback = void Function();
        typedef void Callback2();
        typedef Future<T> Callback3<T>();
        class Foo {
          dynamic f(Callback c) {}
          dynamic g(Callback2 c) {}
          dynamic h(Callback3<Foo> c) {}
        }
        '''),
      },
      outputs: {
        'foo|test/foo_test.mocks.dart': dedent(r'''
        import 'package:mockito/mockito.dart' as _i1;
        import 'package:foo/foo.dart' as _i2;

        /// A class which mocks [Foo].
        ///
        /// See the documentation for Mockito's code generation for more information.
        class MockFoo extends _i1.Mock implements _i2.Foo {
          dynamic f(_i2.Callback c) => super.noSuchMethod(Invocation.method(#f, [c]));
          dynamic g(_i2.Callback2 c) => super.noSuchMethod(Invocation.method(#g, [c]));
          dynamic h(_i2.Callback3<_i2.Foo> c) =>
              super.noSuchMethod(Invocation.method(#h, [c]));
        }
        '''),
      },
    );
  });

  test('imports libraries for function types with external types', () async {
    await _testWithNonNullable(
      {
        ...annotationsAsset,
        ...simpleTestAsset,
        'foo|lib/foo.dart': dedent(r'''
        import 'dart:async';
        class Foo {
          dynamic f(Foo c()) {}
          dynamic g(void c(Foo f)) {}
          dynamic h(void c(Foo f, [Foo g])) {}
          dynamic i(void c(Foo f, {Foo g})) {}
          dynamic j(Foo Function() c) {}
          dynamic k(void Function(Foo f) c) {}
        }
        '''),
      },
      outputs: {
        'foo|test/foo_test.mocks.dart': dedent(r'''
        import 'package:mockito/mockito.dart' as _i1;
        import 'package:foo/foo.dart' as _i2;

        /// A class which mocks [Foo].
        ///
        /// See the documentation for Mockito's code generation for more information.
        class MockFoo extends _i1.Mock implements _i2.Foo {
          dynamic f(_i2.Foo Function() c) =>
              super.noSuchMethod(Invocation.method(#f, [c]));
          dynamic g(void Function(_i2.Foo) c) =>
              super.noSuchMethod(Invocation.method(#g, [c]));
          dynamic h(void Function(_i2.Foo, [_i2.Foo]) c) =>
              super.noSuchMethod(Invocation.method(#h, [c]));
          dynamic i(void Function(_i2.Foo, {_i2.Foo g}) c) =>
              super.noSuchMethod(Invocation.method(#i, [c]));
          dynamic j(_i2.Foo Function() c) =>
              super.noSuchMethod(Invocation.method(#j, [c]));
          dynamic k(void Function(_i2.Foo) c) =>
              super.noSuchMethod(Invocation.method(#k, [c]));
        }
        '''),
      },
    );
  });

  test('correctly matches nullability of parameters', () async {
    await _testWithNonNullable(
      {
        ...annotationsAsset,
        ...simpleTestAsset,
        'foo|lib/foo.dart': dedent(r'''
        abstract class Foo {
          void f(int? a, int b);
          void g(List<int?> a, List<int> b);
          void h(int? Function() a, int Function() b);
          void i(void Function(int?) a, void Function(int) b);
          void j(int? a(), int b());
          void k(void a(int? x), void b(int x));
          void l<T>(T? a, T b);
        }
        '''),
      },
      outputs: {
        // TODO(srawlins): The type of l's first parameter should be `T?`.
        'foo|test/foo_test.mocks.dart': dedent(r'''
        import 'package:mockito/mockito.dart' as _i1;
        import 'package:foo/foo.dart' as _i2;

        /// A class which mocks [Foo].
        ///
        /// See the documentation for Mockito's code generation for more information.
        class MockFoo extends _i1.Mock implements _i2.Foo {
          void f(int? a, int b) => super.noSuchMethod(Invocation.method(#f, [a, b]));
          void g(List<int?> a, List<int> b) =>
              super.noSuchMethod(Invocation.method(#g, [a, b]));
          void h(int? Function() a, int Function() b) =>
              super.noSuchMethod(Invocation.method(#h, [a, b]));
          void i(void Function(int?) a, void Function(int) b) =>
              super.noSuchMethod(Invocation.method(#i, [a, b]));
          void j(int? Function() a, int Function() b) =>
              super.noSuchMethod(Invocation.method(#j, [a, b]));
          void k(void Function(int?) a, void Function(int) b) =>
              super.noSuchMethod(Invocation.method(#k, [a, b]));
          void l<T>(T a, T b) => super.noSuchMethod(Invocation.method(#l, [a, b]));
        }
        '''),
      },
    );
  });

  test('correctly matches nullability of return types', () async {
    await _testWithNonNullable(
      {
        ...annotationsAsset,
        ...simpleTestAsset,
        'foo|lib/foo.dart': dedent(r'''
        abstract class Foo {
          int f();
          int? g();
          List<int?> h();
          List<int> i();
        }
        '''),
      },
      outputs: {
        'foo|test/foo_test.mocks.dart': dedent(r'''
        import 'package:mockito/mockito.dart' as _i1;
        import 'package:foo/foo.dart' as _i2;

        /// A class which mocks [Foo].
        ///
        /// See the documentation for Mockito's code generation for more information.
        class MockFoo extends _i1.Mock implements _i2.Foo {
          int f() => super.noSuchMethod(Invocation.method(#f, []), 0);
          int? g() => super.noSuchMethod(Invocation.method(#g, []), 0);
          List<int?> h() => super.noSuchMethod(Invocation.method(#h, []), []);
          List<int> i() => super.noSuchMethod(Invocation.method(#i, []), []);
        }
        '''),
      },
    );
  });

  test('overrides abstract methods', () async {
    await _testWithNonNullable(
      {
        ...annotationsAsset,
        ...simpleTestAsset,
        'foo|lib/foo.dart': dedent(r'''
        abstract class Foo {
          dynamic f(int a);
          dynamic _g(int a);
        }
        '''),
      },
      outputs: {
        'foo|test/foo_test.mocks.dart': dedent(r'''
        import 'package:mockito/mockito.dart' as _i1;
        import 'package:foo/foo.dart' as _i2;

        /// A class which mocks [Foo].
        ///
        /// See the documentation for Mockito's code generation for more information.
        class MockFoo extends _i1.Mock implements _i2.Foo {
          dynamic f(int a) => super.noSuchMethod(Invocation.method(#f, [a]));
        }
        '''),
      },
    );
  });

  test('does not override methods with all nullable parameters', () async {
    await _testWithNonNullable(
      {
        ...annotationsAsset,
        ...simpleTestAsset,
        'foo|lib/foo.dart': dedent(r'''
          class Foo {
            void a(int? m) {}
            void b(dynamic n) {}
            void c(int Function()? o) {}
          }
          '''),
      },
      outputs: {
        'foo|test/foo_test.mocks.dart': dedent(r'''
          import 'package:mockito/mockito.dart' as _i1;
          import 'package:foo/foo.dart' as _i2;

          /// A class which mocks [Foo].
          ///
          /// See the documentation for Mockito's code generation for more information.
          class MockFoo extends _i1.Mock implements _i2.Foo {}
          '''),
      },
    );
  });

  test('overrides methods with a potentially non-nullable parameter', () async {
    await _testWithNonNullable(
      {
        ...annotationsAsset,
        ...simpleTestAsset,
        'foo|lib/foo.dart': dedent(r'''
        class Foo<T> {
          void a(T m) {}
        }
        '''),
      },
      outputs: {
        'foo|test/foo_test.mocks.dart': dedent(r'''
        import 'package:mockito/mockito.dart' as _i1;
        import 'package:foo/foo.dart' as _i2;

        /// A class which mocks [Foo].
        ///
        /// See the documentation for Mockito's code generation for more information.
        class MockFoo<T> extends _i1.Mock implements _i2.Foo<T> {
          void a(T m) => super.noSuchMethod(Invocation.method(#a, [m]));
        }
        '''),
      },
    );
  });

  test('overrides generic methods', () async {
    await _testWithNonNullable(
      {
        ...annotationsAsset,
        ...simpleTestAsset,
        'foo|lib/foo.dart': dedent(r'''
        class Foo {
          dynamic f<T>(int a) {}
          dynamic g<T extends Foo>(int a) {}
        }
        '''),
      },
      outputs: {
        // TODO(srawlins): The getter will appear when it has a non-nullable
        // return type.
        'foo|test/foo_test.mocks.dart': dedent(r'''
        import 'package:mockito/mockito.dart' as _i1;
        import 'package:foo/foo.dart' as _i2;

        /// A class which mocks [Foo].
        ///
        /// See the documentation for Mockito's code generation for more information.
        class MockFoo extends _i1.Mock implements _i2.Foo {
          dynamic f<T>(int a) => super.noSuchMethod(Invocation.method(#f, [a]));
          dynamic g<T extends _i2.Foo>(int a) =>
              super.noSuchMethod(Invocation.method(#g, [a]));
        }
        '''),
      },
    );
  });

  test('overrides getters and setters', () async {
    await _testWithNonNullable(
      {
        ...annotationsAsset,
        ...simpleTestAsset,
        'foo|lib/foo.dart': dedent(r'''
        class Foo {
          int get a => n + 1;
          int _b;
          set b(int value) => _b = value;
        }
        '''),
      },
      outputs: {
        // TODO(srawlins): The getter will appear when it has a non-nullable
        // return type.
        'foo|test/foo_test.mocks.dart': dedent(r'''
        import 'package:mockito/mockito.dart' as _i1;
        import 'package:foo/foo.dart' as _i2;

        /// A class which mocks [Foo].
        ///
        /// See the documentation for Mockito's code generation for more information.
        class MockFoo extends _i1.Mock implements _i2.Foo {
          set b(int value) => super.noSuchMethod(Invocation.setter(#b, [value]));
        }
        '''),
      },
    );
  });

  test('overrides operators', () async {
    await _testWithNonNullable(
      {
        ...annotationsAsset,
        ...simpleTestAsset,
        'foo|lib/foo.dart': dedent(r'''
        class Foo {
          int _b;
          int operator +(Foo other) => _b + other._b;
          bool operator ==(Object other) => other is Foo && _b == other._b;
        }
        '''),
      },
      outputs: {
        'foo|test/foo_test.mocks.dart': dedent(r'''
        import 'package:mockito/mockito.dart' as _i1;
        import 'package:foo/foo.dart' as _i2;

        /// A class which mocks [Foo].
        ///
        /// See the documentation for Mockito's code generation for more information.
        class MockFoo extends _i1.Mock implements _i2.Foo {
          int operator +(_i2.Foo other) =>
              super.noSuchMethod(Invocation.method(#+, [other]), 0);
          bool operator ==(Object other) =>
              super.noSuchMethod(Invocation.method(#==, [other]), false);
        }
        '''),
      },
    );
  });

  test('creates dummy non-null return values for known core classes', () async {
    await _testWithNonNullable(
      {
        ...annotationsAsset,
        ...simpleTestAsset,
        'foo|lib/foo.dart': dedent(r'''
        class Foo {
          bool m1() => false;
          double m2() => 3.14;
          int m3() => 7;
          String m4() => "Hello";
          List<Foo> m5() => [Foo()];
          Set<Foo> m6() => {Foo()};
          Map<int, Foo> m7() => {7: Foo()};
        }
        '''),
      },
      outputs: {
        'foo|test/foo_test.mocks.dart': dedent(r'''
        import 'package:mockito/mockito.dart' as _i1;
        import 'package:foo/foo.dart' as _i2;

        /// A class which mocks [Foo].
        ///
        /// See the documentation for Mockito's code generation for more information.
        class MockFoo extends _i1.Mock implements _i2.Foo {
          bool m1() => super.noSuchMethod(Invocation.method(#m1, []), false);
          double m2() => super.noSuchMethod(Invocation.method(#m2, []), 0.0);
          int m3() => super.noSuchMethod(Invocation.method(#m3, []), 0);
          String m4() => super.noSuchMethod(Invocation.method(#m4, []), '');
          List<_i2.Foo> m5() => super.noSuchMethod(Invocation.method(#m5, []), []);
          Set<_i2.Foo> m6() => super.noSuchMethod(Invocation.method(#m6, []), {});
          Map<int, _i2.Foo> m7() => super.noSuchMethod(Invocation.method(#m7, []), {});
        }
        '''),
      },
    );
  });

  test('creates dummy non-null return values for Futures of known core classes',
      () async {
    await _testWithNonNullable(
      {
        ...annotationsAsset,
        ...simpleTestAsset,
        'foo|lib/foo.dart': dedent(r'''
        class Foo {
          Future<bool> m1() async => false;
        }
        '''),
      },
      outputs: {
        'foo|test/foo_test.mocks.dart': dedent(r'''
        import 'package:mockito/mockito.dart' as _i1;
        import 'package:foo/foo.dart' as _i2;
        import 'dart:async' as _i3;

        /// A class which mocks [Foo].
        ///
        /// See the documentation for Mockito's code generation for more information.
        class MockFoo extends _i1.Mock implements _i2.Foo {
          _i3.Future<bool> m1() async =>
              super.noSuchMethod(Invocation.method(#m1, []), Future.value(false));
        }
        '''),
      },
    );
  });

  test('creates dummy non-null return values for unknown classes', () async {
    await _testWithNonNullable(
      {
        ...annotationsAsset,
        ...simpleTestAsset,
        'foo|lib/foo.dart': dedent(r'''
        class Foo {
          Bar m1() => Bar('name');
        }
        class Bar {
          final String name;
          Bar(this.name);
        }
        '''),
      },
      outputs: {
        'foo|test/foo_test.mocks.dart': dedent(r'''
        import 'package:mockito/mockito.dart' as _i1;
        import 'package:foo/foo.dart' as _i2;

        class _FakeBar extends _i1.Fake implements _i2.Bar {}

        /// A class which mocks [Foo].
        ///
        /// See the documentation for Mockito's code generation for more information.
        class MockFoo extends _i1.Mock implements _i2.Foo {
          _i2.Bar m1() => super.noSuchMethod(Invocation.method(#m1, []), _FakeBar());
        }
        '''),
      },
    );
  });

  test('deduplicates fake classes', () async {
    await _testWithNonNullable(
      {
        ...annotationsAsset,
        ...simpleTestAsset,
        'foo|lib/foo.dart': dedent(r'''
        class Foo {
          Bar m1() => Bar('name1');
          Bar m2() => Bar('name2');
        }
        class Bar {
          final String name;
          Bar(this.name);
        }
        '''),
      },
      outputs: {
        'foo|test/foo_test.mocks.dart': dedent(r'''
        import 'package:mockito/mockito.dart' as _i1;
        import 'package:foo/foo.dart' as _i2;

        class _FakeBar extends _i1.Fake implements _i2.Bar {}

        /// A class which mocks [Foo].
        ///
        /// See the documentation for Mockito's code generation for more information.
        class MockFoo extends _i1.Mock implements _i2.Foo {
          _i2.Bar m1() => super.noSuchMethod(Invocation.method(#m1, []), _FakeBar());
          _i2.Bar m2() => super.noSuchMethod(Invocation.method(#m2, []), _FakeBar());
        }
        '''),
      },
    );
  });

  test('creates dummy non-null return values for enums', () async {
    await _testWithNonNullable(
      {
        ...annotationsAsset,
        ...simpleTestAsset,
        'foo|lib/foo.dart': dedent(r'''
        class Foo {
          Bar m1() => Bar('name');
        }
        enum Bar {
          one,
          two,
        }
        '''),
      },
      outputs: {
        'foo|test/foo_test.mocks.dart': dedent(r'''
        import 'package:mockito/mockito.dart' as _i1;
        import 'package:foo/foo.dart' as _i2;

        /// A class which mocks [Foo].
        ///
        /// See the documentation for Mockito's code generation for more information.
        class MockFoo extends _i1.Mock implements _i2.Foo {
          _i2.Bar m1() => super.noSuchMethod(Invocation.method(#m1, []), _i2.Bar.one);
        }
        '''),
      },
    );
  });

  test('creates dummy non-null return values for functions', () async {
    await _testWithNonNullable(
      {
        ...annotationsAsset,
        ...simpleTestAsset,
        'foo|lib/foo.dart': dedent(r'''
        class Foo {
          void Function(int, [String]) m1() => (int i, [String s]) {};
          void Function(Foo, {bool b}) m2() => (Foo f, {bool b}) {};
          Foo Function() m3() => () => Foo();
        }
        '''),
      },
      outputs: {
        'foo|test/foo_test.mocks.dart': dedent(r'''
        import 'package:mockito/mockito.dart' as _i1;
        import 'package:foo/foo.dart' as _i2;

        class _FakeFoo extends _i1.Fake implements _i2.Foo {}

        /// A class which mocks [Foo].
        ///
        /// See the documentation for Mockito's code generation for more information.
        class MockFoo extends _i1.Mock implements _i2.Foo {
          void Function(int, [String]) m1() => super
              .noSuchMethod(Invocation.method(#m1, []), (int __p0, [String __p1]) {});
          void Function(_i2.Foo, {bool b}) m2() => super
              .noSuchMethod(Invocation.method(#m2, []), (_i2.Foo __p0, {bool b}) {});
          _i2.Foo Function() m3() =>
              super.noSuchMethod(Invocation.method(#m3, []), () => _FakeFoo());
        }
        '''),
      },
    );
  });

  test('throws when GenerateMocks references an unresolved type', () async {
    expectBuilderThrows(
      assets: {
        ...annotationsAsset,
        'foo|lib/foo.dart': dedent(r'''
        class Foo {}
        '''),
        'foo|test/foo_test.dart': dedent('''
        // missing foo.dart import.
        import 'package:mockito/annotations.dart';
        @GenerateMocks([List, Foo])
        void main() {}
        '''),
      },
      message: 'The "classes" argument has unknown types',
    );
  });

  test('throws when GenerateMocks references a non-type', () async {
    expectBuilderThrows(
      assets: {
        ...annotationsAsset,
        'foo|lib/foo.dart': dedent(r'''
        class Foo {}
        '''),
        'foo|test/foo_test.dart': dedent('''
        // missing foo.dart import.
        import 'package:mockito/annotations.dart';
        @GenerateMocks([7])
        void main() {}
        '''),
      },
      message: 'The "classes" argument includes a non-type: int (7)',
    );
  });

  test('throws when GenerateMocks references a typedef', () async {
    expectBuilderThrows(
      assets: {
        ...annotationsAsset,
        ...simpleTestAsset,
        'foo|lib/foo.dart': dedent(r'''
        typedef Foo = void Function();
        '''),
      },
      message: 'The "classes" argument includes a typedef: Foo',
    );
  });

  test('throws when GenerateMocks references an enum', () async {
    expectBuilderThrows(
      assets: {
        ...annotationsAsset,
        ...simpleTestAsset,
        'foo|lib/foo.dart': dedent(r'''
        enum Foo {}
        '''),
      },
      message: 'The "classes" argument includes an enum: Foo',
    );
  });

  test('given a pre-non-nullable library, does not override any members',
      () async {
    await _testPreNonNullable(
      {
        ...annotationsAsset,
        ...simpleTestAsset,
        'foo|lib/foo.dart': dedent(r'''
        abstract class Foo {
          dynamic f(int a) {}
        }
        '''),
      },
      outputs: {
        'foo|test/foo_test.mocks.dart': dedent(r'''
        import 'package:mockito/mockito.dart' as _i1;
        import 'package:foo/foo.dart' as _i2;

        /// A class which mocks [Foo].
        ///
        /// See the documentation for Mockito's code generation for more information.
        class MockFoo extends _i1.Mock implements _i2.Foo {}
        '''),
      },
    );
  });
}

/// Test [MockBuilder] in a package which has not opted into the non-nullable
/// type system.
///
/// Whether the non-nullable experiment is enabled depends on the SDK executing
/// this test, but that does not affect the opt-in state of the package under
/// test.
Future<void> _testPreNonNullable(Map<String, String> sourceAssets,
    {Map<String, /*String|Matcher<String>*/ dynamic> outputs}) async {
  var packageConfig = PackageConfig([
    Package('foo', Uri.file('/foo/'),
        packageUriRoot: Uri.file('/foo/lib/'),
        languageVersion: LanguageVersion(2, 7))
  ]);
  await testBuilder(buildMocks(BuilderOptions({})), sourceAssets,
      outputs: outputs, packageConfig: packageConfig);
}

/// Test [MockBuilder] in a package which has opted into the non-nullable type
/// system, and with the non-nullable experiment enabled.
Future<void> _testWithNonNullable(Map<String, String> sourceAssets,
    {Map<String, /*String|Matcher<String>*/ dynamic> outputs}) async {
  var packageConfig = PackageConfig([
    Package('foo', Uri.file('/foo/'),
        packageUriRoot: Uri.file('/foo/lib/'),
        languageVersion: LanguageVersion(2, 9))
  ]);
  await withEnabledExperiments(
    () async => await testBuilder(buildMocks(BuilderOptions({})), sourceAssets,
        outputs: outputs, packageConfig: packageConfig),
    ['non-nullable'],
  );
}

/// Expect that [testBuilder], given [assets], throws an
/// [InvalidMockitoAnnotationException] with a message containing [message].
void expectBuilderThrows(
    {@required Map<String, String> assets, @required String message}) {
  expect(
      () async => await testBuilder(buildMocks(BuilderOptions({})), assets),
      throwsA(TypeMatcher<InvalidMockitoAnnotationException>()
          .having((e) => e.message, 'message', contains(message))));
}

/// Dedent [input], so that each line is shifted to the left, so that the first
/// line is at the 0 column.
String dedent(String input) {
  final indentMatch = RegExp(r'^(\s*)').firstMatch(input);
  final indent = ''.padRight(indentMatch.group(1).length);
  return input.splitMapJoin('\n',
      onNonMatch: (s) => s.replaceFirst(RegExp('^$indent'), ''));
}