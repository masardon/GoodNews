# Use a Python base image
FROM python:3.9

# Set the working directory inside the container
WORKDIR /app

# Copy the requirements.txt file and install the dependencies
COPY dependency.txt .
RUN pip install --no-cache-dir -r dependency.txt

# Copy the backend, data, and creds folders to the working directory inside the container
COPY backend ./backend
COPY data ./data
COPY creds ./creds

# Expose the port that the application will use
EXPOSE 8000

# The command to run the application
CMD ["uvicorn", "backend.main:app", "--host", "0.0.0.0", "--port", "8000"]
