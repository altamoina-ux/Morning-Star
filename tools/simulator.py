"""软件联调模拟器：模拟 ESP32 在线、心跳和 JPEG 图像上传。"""
import asyncio, json, os, struct, time
import cv2, numpy as np
import websockets

URL=os.getenv("QH_DEVICE_WS","ws://127.0.0.1:8765/ws/device")
DEVICE_ID=os.getenv("QH_DEVICE_ID","simulator_001")

def image(seq):
    canvas=np.zeros((480,640,3),np.uint8); canvas[:]=(18,35,60)
    cv2.rectangle(canvas,(80,60),(260,360),(40,170,230),3)
    cv2.putText(canvas,"SIMULATED CAMERA",(160,440),cv2.FONT_HERSHEY_SIMPLEX,.8,(100,220,255),2)
    ok, encoded=cv2.imencode(".jpg",canvas,[cv2.IMWRITE_JPEG_QUALITY,80])
    return encoded.tobytes()

def frame(payload,seq):
    header=b"QH"+bytes([1,1])+struct.pack("<H",26)+struct.pack("<I",seq)+struct.pack("<Q",int(time.time()*1000))+struct.pack("<HHI",0,1,len(payload))
    return header+payload

async def main():
    async with websockets.connect(URL) as ws:
        await ws.send(json.dumps({"type":"device_online","device_id":DEVICE_ID,"firmware_version":"sim-0.1","timestamp":time.time()}))
        seq=0
        while True:
            seq+=1
            await ws.send(frame(image(seq),seq))
            await ws.send(json.dumps({"type":"heartbeat","device_id":DEVICE_ID,"camera_ok":True,"mic_ok":True,"timestamp":time.time()}))
            await asyncio.sleep(1)

if __name__=="__main__": asyncio.run(main())
