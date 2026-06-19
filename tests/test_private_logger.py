import tempfile
import unittest
import sys
from pathlib import Path

sys.argv = [sys.argv[0]]

from modules.flags import OutputFormat
from modules.private_logger import make_custom_filename_path, make_unique_filename_path


class TestPrivateLogger(unittest.TestCase):
    def test_custom_filename_sanitizes_and_uses_output_format(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = make_custom_filename_path(directory, OutputFormat.PNG.value, '../bad:name?.jpg')

            self.assertEqual(path, str(root / 'bad_name.png'))

    def test_custom_jpeg_filename_preserves_jpg_extension(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = make_custom_filename_path(directory, OutputFormat.JPEG.value, 'portrait.jpg')

            self.assertEqual(path, str(root / 'portrait.jpg'))

    def test_unique_filename_uses_next_numbered_suffix(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            base = root / 'supermodel-with-purple-lambo.png'
            second = root / 'supermodel-with-purple-lambo-2.png'
            base.write_bytes(b'first')
            second.write_bytes(b'second')

            path = make_unique_filename_path(str(base))

            self.assertEqual(path, str(root / 'supermodel-with-purple-lambo-3.png'))


if __name__ == '__main__':
    unittest.main()
