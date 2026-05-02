import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/core/utils/misc.dart';

void main() {
  group('stripHtml tests', () {
    group('Empty inputs', () {
      test('Empty string should return empty string', () {
        expect(stripHtml(''), '');
      });

      test('Empty HTML tags should return empty string', () {
        expect(stripHtml('<p></p>'), '');
        expect(stripHtml('<div></div>'), '');
        expect(stripHtml('<strong></strong>'), '');
      });

      test('Whitespace-only after stripping should return empty string', () {
        expect(stripHtml('<p>   </p>'), '');
        expect(stripHtml('<p>\t</p>'), '');
        expect(stripHtml('<p>\n</p>'), '');
      });
    });

    group('Basic HTML stripping', () {
      test('Simple tags should be removed', () {
        expect(stripHtml('<p>Hello</p>'), 'Hello');
        expect(stripHtml('<strong>Bold</strong>'), 'Bold');
        expect(stripHtml('<em>Italic</em>'), 'Italic');
      });

      test('Nested tags should be removed', () {
        expect(stripHtml('<p>Hello <strong>world</strong></p>'), 'Hello world');
        expect(stripHtml('<div><p>Nested <em>content</em></p></div>'),
            'Nested content');
      });

      test('Multiple tags should all be removed', () {
        expect(stripHtml('<p>This <b>is</b> <i>a</i> <u>test</u></p>'),
            'This is a test');
      });

      test('Self-closing tags should be removed', () {
        expect(stripHtml('<p>Text<br/>More</p>'), 'TextMore');
        expect(stripHtml('<p>Text<hr/>More</p>'), 'TextMore');
      });
    });

    group('HTML entity decoding', () {
      test('&nbsp; should be converted to space', () {
        expect(stripHtml('Hello&nbsp;world'), 'Hello world');
        expect(stripHtml('<p>A&nbsp;B&nbsp;C</p>'), 'A B C');
      });

      test('&amp; should be converted to &', () {
        expect(stripHtml('Tom &amp; Jerry'), 'Tom & Jerry');
        expect(stripHtml('<p>A &amp; B</p>'), 'A & B');
      });

      test('&lt; should be converted to <', () {
        expect(stripHtml('a &lt; b'), 'a < b');
        expect(stripHtml('<p>1 &lt; 2</p>'), '1 < 2');
      });

      test('&gt; should be converted to >', () {
        expect(stripHtml('a &gt; b'), 'a > b');
        expect(stripHtml('<p>2 &gt; 1</p>'), '2 > 1');
      });

      test('&quot; should be converted to "', () {
        expect(stripHtml('&quot;quoted&quot;'), '"quoted"');
        expect(stripHtml('<p>&quot;Hello&quot;</p>'), '"Hello"');
      });

      test('&#39; should be converted to \'', () {
        expect(stripHtml("It&#39;s working"), "It's working");
        expect(stripHtml("<p>Don&#39;t</p>"), "Don't");
      });

      test('Multiple entities should all be decoded', () {
        expect(stripHtml('A &amp; B &lt; C &gt; D &quot;E&quot; F&#39;s'),
            'A & B < C > D "E" F\'s');
      });
    });

    group('Combined HTML and entities', () {
      test('Tags and entities together should be handled correctly', () {
        expect(stripHtml('<p>Tom &amp; Jerry</p>'), 'Tom & Jerry');
        expect(stripHtml('<p>a &lt; b &gt; c</p>'), 'a < b > c');
        expect(stripHtml('<div>&quot;Hello&quot;</div>'), '"Hello"');
      });

      test('Complex nested structure with entities', () {
        expect(
          stripHtml(
              '<div><p>This &amp; <strong>that</strong> &quot;stuff&quot;</p></div>'),
          'This & that "stuff"',
        );
      });
    });

    group('Whitespace trimming', () {
      test('Leading whitespace should be trimmed', () {
        expect(stripHtml('   Hello'), 'Hello');
        expect(stripHtml('\t\nHello'), 'Hello');
        expect(stripHtml('<p>   Hello</p>'), 'Hello');
      });

      test('Trailing whitespace should be trimmed', () {
        expect(stripHtml('Hello   '), 'Hello');
        expect(stripHtml('Hello\t\n'), 'Hello');
        expect(stripHtml('<p>Hello   </p>'), 'Hello');
      });

      test('Both leading and trailing whitespace should be trimmed', () {
        expect(stripHtml('   Hello   '), 'Hello');
        expect(stripHtml('   <p>Hello</p>   '), 'Hello');
      });

      test('Internal whitespace should be preserved', () {
        expect(stripHtml('Hello   world'), 'Hello   world');
        expect(stripHtml('<p>Hello   world</p>'), 'Hello   world');
      });
    });

    group('Real-world scenarios', () {
      test('Empty paragraph from WYSIWYG editor (the original bug)', () {
        expect(stripHtml('<p></p>'), '');
      });

      test('Paragraph with only whitespace', () {
        expect(stripHtml('<p>   </p>'), '');
      });

      test('Normal rich-text content', () {
        expect(
          stripHtml(
              '<p>This is a <strong>description</strong> with <em>formatting</em>.</p>'),
          'This is a description with formatting.',
        );
      });

      test('Content with special characters', () {
        expect(stripHtml('<p>Check this out: a &lt; b &amp; c &gt; d</p>'),
            'Check this out: a < b & c > d');
      });

      test('Multiple paragraphs', () {
        expect(stripHtml('<p>First</p><p>Second</p>'), 'FirstSecond');
      });

      test('Content with line breaks converted to spaces', () {
        expect(stripHtml('<p>Line1<br/>Line2</p>'), 'Line1Line2');
      });
    });
  });
}
