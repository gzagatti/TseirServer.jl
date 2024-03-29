FROM julia:1.6

# user
RUN useradd --create-home --shell /bin/bash genie

# app
RUN mkdir /home/genie/app
COPY . /home/genie/app
WORKDIR /home/genie/app

RUN chown genie:genie -R *

RUN chmod +x bin/repl
RUN chmod +x bin/server
RUN chmod +x bin/runtask

USER genie

RUN julia -e "using Pkg; Pkg.activate(\".\"); Pkg.instantiate(); Pkg.precompile(); "

# ports
EXPOSE 8000

ENV JULIA_DEPOT_PATH "/home/genie/.julia"
ENV GENIE_ENV "prod"
ENV HOST "0.0.0.0"
ENV PORT "8000"

CMD ["bin/server"]
