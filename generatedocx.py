import os
from pdf2docx.reader import Reader
from pdf2docx.writer import Writer

dir_output = '/path/to/output/dir/'
filename = 'demo-text'
pdf_file = os.path.join(dir_output, f'{filename}.pdf')
docx_file = os.path.join(dir_output, f'{filename}.docx')

pdf = Reader(pdf_file, debug=True)  # debug mode to plot layout in new PDF file
docx = Writer()

for page in pdf[0:1]:
    # parse raw layout
    layout = pdf.parse(page)
    # re-create docx page
    docx.make_page(layout)

docx.save(docx_file)
pdf.close()