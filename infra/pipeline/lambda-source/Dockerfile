FROM public.ecr.aws/lambda/python:3.9-x86_64

# Install the function's dependencies using file requirements.txt
# from your project folder.
COPY requirements.txt  .
# COPY --from=parent requirements.txt  .
RUN pip3 install -r requirements.txt --target "${LAMBDA_TASK_ROOT}"
# Copy function code
COPY src/ ${LAMBDA_TASK_ROOT}
#ENV TMPDIR=/tmp
# Set the CMD to your handler (could also be done as a parameter override outside of the Dockerfile)
CMD [ "app.handler" ]