#-*-coding:utf-8-*-
import socket
import gevent
import gevent.socket
import gevent.event

def test(i):
	sock=gevent.socket.create_connection(('127.0.0.1',16000))
	# sock.shutdown(socket.SHUT_WR)
	# return
	x =str(i)*10
	print x

	count = 0 
	while True:
		# s=sock.recv(1024)
		# print s
		# sock.sendall(x)
		# count += 1
		# if count >100 :
		# 	gevent.sleep(0)
		# 	count  = 0 


		# sock.sendall('<'+str(i)+'>')
		
		if i==6:
			sock.sendall(x)
		else:
			s=sock.recv(1024)
	

		#gevent.sleep(1)

def entry():
	lJob=[]
	for i in xrange(7):
		job=gevent.spawn(test,i)  #
		lJob.append(job)

	gevent.joinall(lJob)




entry()



