FROM python:3.12
ADD requirements.txt /
RUN pip install -r /requirements.txt
RUN mkdir /anvilfolder/
RUN chmod -R 777 /anvilfolder
ADD connect4_backend.py /
ENV PYTHONUNBUFFERED=1
CMD [ "python", "./connect4_backend.py" ]