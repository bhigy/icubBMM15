
var express = require('express');
var app = express();
var http = require('http').Server(app);
var io = require('socket.io')(http);
var net = require('net');
var sys = require('sys');
var spawn = require('child_process').spawn;
var os = require('os');


var client=new net.Socket();

// serving pages
app.get('/', function(req, res){
  res.sendFile(__dirname + '/public/index.html');
});

app.use(express.static('./public'));
app.use(express.static('./node_modules/jquery/dist'));
app.use(express.static('./node_modules/bootstrap/dist'));







function connectToYarpPort(port_name)
{
  //get the port name
  child = spawn('yarp',['name','query',port_name]);


  child.stderr.on('data', function (data) {
    io.emit('connection closed');
    io.emit('reply from server',data.toString());
  });



  child.stdout.on('data', function (data) { 

      response = data.toString();
      var idx_ip = response.indexOf('ip');
      var idx_port = response.indexOf('port');
      var idx_type = response.indexOf('type');

      host = response.substring(idx_ip+3,idx_port-1);
      port=response.substring(idx_port+5,idx_type-1);

      client = net.connect(port,host, function() { //'connect' listener
       client.write('CONNECT Yarpino\nj\n');
        //client.write('Y'A' 0x61 0x1E 0 0 R'P'')
        
        // send the message to notify the client that we got disconnected
        client.on('end',function(){
          io.emit('connection closed');
        });

        client.on('data', function(data) {
          console.log('####'+data.toString());

          // if(data.toString().substr(0,6)=='Welcome')
          //   io.emit('reply from server',data.toString());

          if(data.toString().length<90)
          {
            io.emit('reply from server',data.toString());
          }

          if(data.toString().length>=90)
            io.emit('reinstate writing');

          if(data.toString().length>90)
            io.emit('reply from server',data.toString().substr(0,data.toString().length-90));
        });
      });

   });


}



io.on('connection', function(socket){

  socket.on('chat message', function(msg){
    client.write('d\n '+msg.toString()+' \nj\n');
  });

  socket.on('open connection', function(port_name){
    connectToYarpPort(port_name);
  });


  socket.on('close connection',function(){
    client.end();
  });

});


var custom_port = '3000';
if(process.argv.indexOf('--port') != -1)
  custom_port=process.argv[process.argv.indexOf("--port") + 1];


var custom_host = '127.0.0.1';
if(process.argv.indexOf('--host') == -1)
{
  // find the current ip and run server there
  var ifaces = os.networkInterfaces();

  var iface_val;
  if(ifaces.hasOwnProperty('en0'))
    iface_val='en0';
  else if(ifaces.hasOwnProperty('eth0'))
    iface_val='eth0';


  for(idx_iface in ifaces[iface_val])
    if(ifaces[iface_val][idx_iface].family=='IPv4')
      custom_host=ifaces[iface_val][idx_iface].address;
}
else
  custom_host = process.argv[process.argv.indexOf("--host") + 1];



// finally, start the server!
http.listen(custom_port,custom_host, function(){
    console.log('listening on '+custom_host+':'+custom_port);
  });

