function DreamV3Regression(_g) {
    var result={lines:[],failed:0,check:function(ok,label) { array_push(lines,(ok?"PASS ":"FAIL ")+label); if(!ok) failed++; }};
    var check=result.check;
    check(array_length(_g.all_sprites)==17,"17 source images loaded");
    check(!_g.begin_drag(0,_g.slots[0],_g.library_y),"cannot pick a sticker before begin");
    check(array_length(_g.stickers)==0,"ready board remains empty");
    _g.start();
    check(_g.mode=="playing","begin starts running");
    for(var k=0;k<3;k++) {
        var seen=array_create(_g.counts[k],false);
        for(var i=0;i<_g.counts[k];i++) {
            var n=_g.peek(k,0), next=_g.peek(k,1);
            check(!seen[n],"shuffle unique "+string(k)+":"+string(n));
            seen[n]=true; _g.advance_bag(k);
            check(_g.peek(k,0)==next,"next artwork agrees across bag boundaries");
        }
    }
    _g.reset(); _g.start();
    var first=_g.peek(0,0);
    _g.begin_drag(0,_g.slots[0],_g.library_y);
    check(!_g.finish_drag(_g.slots[0],_g.library_y),"return to library cancels");
    check(_g.peek(0,0)==first && _g.heads[0]==0,"cancel preserves card");
    _g.player.px=1400; _g.update_camera();
    var camera=_g.camera_x;
    _g.begin_drag(0,_g.slots[0],_g.library_y);
    _g.player.px+=100; _g.update_camera();
    var preview=_g.preview(850,450);
    check(abs(preview.px-_g.camera_x-850)<0.01,"preview stays under cursor while camera moves");
    check(_g.finish_drag(850,450),"scrolled placement succeeds");
    check(abs(_g.stickers[0].px-(_g.camera_x+850))<0.01,"placement uses world coordinates");
    var fixed_x=_g.stickers[0].px;
    _g.player.px+=100; _g.update_camera();
    check(_g.stickers[0].px==fixed_x,"placed sticker stays anchored in world");
    _g.mode="paused";
    check(!_g.begin_drag(1,_g.slots[1],_g.library_y),"paused inventory is locked");
    _g.reset();
    check(_g.camera_x==0 && _g.player.px==100 && array_length(_g.stickers)==0 && _g.mode=="ready","retry resets camera route and gate");
    check(_g.goal_x>_g.width,"exit is initially offscreen");
    _g.start(); repeat(300) _g.physics(1/120);
    check(_g.player.grounded && _g.mode=="playing","at least 2.5 seconds of safe starting ground");
    repeat(300) { if(_g.mode=="playing") _g.physics(1/120); }
    check(_g.mode=="lost","falling ends the run at library boundary");
    _g.reset(); _g.start();
    var s=_g.make_sticker(0,0,900,455); s.top=400; _g.stickers=[s];
    _g.player.px=900; _g.player.py=350; _g.player.vy=9000; _g.player.grounded=false;
    _g.physics(1/120);
    check(_g.player.grounded && abs(_g.player.py-405)<0.1,"swept fast landing");
    _g.reset(); _g.start();
    var ground=_g.make_sticker(0,0,900,455); ground.top=400;
    s=_g.make_sticker(2,0,900,455); s.top=400; _g.stickers=[ground,s];
    _g.player.px=900; _g.player.py=404; _g.player.vy=200; _g.player.grounded=false;
    _g.physics(1/120);
    check(_g.player.state=="rise" && _g.player.vx==_g.run_speed,"spring still launches over ground");
    var apex=_g.player.py;
    repeat(85) { _g.physics(1/120); apex=min(apex,_g.player.py); }
    check(abs(apex-202.5)<8,"spring half-height remains stable");
    // Slow arrivals and multiple rope lengths must all automatically travel to the right.
    for(var variant=0;variant<3;variant++) {
        _g.reset(); _g.start(); s=_g.make_sticker(1,0,900,180); _g.stickers=[s];
        _g.player.px=900-(variant==0?100:45);
        _g.player.py=180+_g.grab_height+(variant==2?80:115);
        _g.player.vx=variant==1?5:135; _g.player.vy=0; _g.player.grounded=false;
        var before_x=_g.player.px, before_y=_g.player.py;
        _g.physics(1/120);
        check(_g.player.state=="swing","capture low/normal entry "+string(variant));
        check(point_distance(before_x,before_y,_g.player.px,_g.player.py)<3,"no position snap on capture");
        var rope=_g.player.rope, released=false;
        repeat(400) {
            if(_g.player.state=="swing") {
                _g.physics(1/120);
                if(_g.player.state=="swing") {
                    if(abs(point_distance(s.px,s.py,_g.player.px,_g.player.py-_g.grab_height)-rope)>0.1) result.failed++;
                } else released=true;
            }
        }
        check(released && _g.player.px>s.px,"automatically exits on the right "+string(variant));
        check(_g.player.vx>0 && _g.player.vy<0,"upward tangent launch "+string(variant));
        _g.physics(1/120);
        check(_g.player.state!="swing" && _g.player.last_hook==0,"release cannot immediately recapture");
        // Put a receiving ledge under the outgoing arc, then require a real landing.
        var landing=_g.make_sticker(0,0,_g.player.px+110,440); landing.top=385;
        array_push(_g.stickers,landing);
        var landed=false;
        repeat(160) { if(_g.mode=="playing") { _g.physics(1/120); if(_g.player.grounded) landed=true; } }
        check(landed,"swing transfer can land on a platform "+string(variant));
    }
    _g.reset(); _g.start();
    for(var xx=530;xx<_g.goal_left;xx+=200) {
        s=_g.make_sticker(0,0,xx,450); s.top=_g.ground_y-5; array_push(_g.stickers,s);
    }
    repeat(5200) { if(_g.mode=="playing") _g.physics(1/120); }
    check(_g.mode=="won","full three-screen route reaches the exit");
    check(abs(_g.camera_x-(_g.level_width-_g.width))<0.01,"camera clamps at level end");

    check(_g.run_speed==100,"walking speed reduced to 100 px per second");
    for(var i=0;i<8;i++) { var art=_g.art_size(0,i); check(art[0]>=199.9,"ground artwork minimum width "+string(i)); }
    // Fixtures use actual sticker support geometry, with independent expected heights.
    _g.reset(); _g.start();
    var f0=DreamTestGround(_g,500,230,405), f1=DreamTestGround(_g,695,230,377), f2=DreamTestGround(_g,890,230,349);
    _g.stickers=[f0,f1,f2]; _g.player.px=650; _g.player.py=405; _g.player.support=0;
    var fell=false, climbed=false;
    repeat(340) { _g.physics(1/120); if(!_g.player.grounded) fell=true; if(abs(_g.player.py-349)<0.1) climbed=true; }
    check(!fell && climbed,"two overlapping steps climb without dropping");
    _g.reset(); _g.start();
    _g.stickers=[DreamTestGround(_g,500,230,320),DreamTestGround(_g,710,230,355),DreamTestGround(_g,920,230,390)];
    _g.player.px=700; _g.player.py=320; _g.player.support=0;
    fell=false;
    repeat(340) { _g.physics(1/120); if(!_g.player.grounded) fell=true; }
    check(!fell && abs(_g.player.py-390)<0.1,"successive 35px down steps keep support");
    _g.reset(); _g.start();
    _g.stickers=[DreamTestGround(_g,500,300,405),DreamTestGround(_g,650,220,380),DreamTestGround(_g,650,220,355)];
    _g.player.px=620; _g.player.py=405; _g.player.support=0;
    repeat(100) _g.physics(1/120);
    check(abs(_g.player.py-380)<0.1,"overlaid levels do not elevator to highest floor");
    _g.reset(); _g.start();
    _g.stickers=[DreamTestGround(_g,500,240,405),DreamTestGround(_g,680,240,365)];
    _g.player.px=650; _g.player.py=405; _g.player.support=0;
    repeat(70) _g.physics(1/120);
    check(_g.player.py>=405,"40px rise is not automatically climbed");
    _g.reset(); _g.start();
    _g.stickers=[DreamTestGround(_g,500,200,405),DreamTestGround(_g,720,200,405)];
    _g.player.px=680; _g.player.py=405; _g.player.support=0; fell=false;
    repeat(100) { _g.physics(1/120); if(!_g.player.grounded) fell=true; }
    check(!fell,"20px seam bridges continuously");
    _g.reset(); _g.start();
    _g.stickers=[DreamTestGround(_g,500,200,405),DreamTestGround(_g,780,200,405)];
    _g.player.px=680; _g.player.py=405; _g.player.support=0; fell=false;
    repeat(95) { _g.physics(1/120); if(!_g.player.grounded) fell=true; }
    check(fell && _g.player.py>405,"80px gap falls normally");
    _g.reset(); _g.start();
    _g.stickers=[DreamTestGround(_g,500,200,405)]; _g.player.px=680; _g.player.py=405; _g.player.support=0;
    repeat(100) _g.physics(1/120);
    check(!_g.player.grounded && _g.player.py>430,"cliff does not create invisible floor");
    _g.reset(); _g.start();
    s=DreamTestGround(_g,495,220,420);
    _g.snap_ground(s,false);
    check(abs(_g.surface_of(s,0).top-405)<0.1 && abs(_g.surface_of(s,0).left-478)<0.1,"near edge snaps both height and seam");
    s=DreamTestGround(_g,495,220,420); _g.snap_ground(s,true);
    check(abs(_g.surface_of(s,0).top-420)<0.1 && abs(_g.surface_of(s,0).left-495)<0.1,"free placement bypasses snapping");
    _g.stickers=[DreamTestGround(_g,700,230,405)];
    s=DreamTestGround(_g,760,230,385); _g.snap_ground(s,false);
    check(abs(_g.surface_of(s,0).top-385)<0.1,"intentional overlapping 20px stair is preserved");
    s=_g.make_sticker(0,1,900,0); var lift=530-(_g.surface_of(s,0).top); s.py+=lift; s.top+=lift;
    check(s.py+s.h/2>_g.play_height && _g.valid_place(s),"decoration can extend below play region");
    s.top=_g.play_height;
    check(!_g.valid_place(s),"support itself cannot be inside library");
    _g.reset(); _g.start();
    s=DreamTestGround(_g,50,200,385);
    check(_g.commit_sticker(s) && abs(_g.player.py-385)<0.1,"placing near feet safely raises runner 20px");
    _g.reset(); _g.start(); s=DreamTestGround(_g,50,200,350);
    check(!_g.valid_place(s),"waist-height insertion is rejected");
    _g.reset(); _g.start(); _g.player.px=850; _g.player.py=420; _g.player.vy=80; _g.player.grounded=false; _g.player.state="fall";
    s=DreamTestGround(_g,750,230,414);
    check(_g.commit_sticker(s) && _g.player.grounded && abs(_g.player.py-414)<0.1,"late low-speed placement rescues feet");
    _g.reset(); _g.start(); _g.player.px=850; _g.player.py=420; _g.player.vy=600; _g.player.grounded=false; _g.player.state="fall";
    s=DreamTestGround(_g,750,230,414);
    check(!_g.commit_sticker(s) && !_g.player.grounded,"fast fall is not teleported upward");
    _g.reset(); _g.start();
    s=DreamTestGround(_g,750,230,405); _g.stickers=[s]; _g.player.px=850; _g.player.py=440; _g.player.vy=-300; _g.player.grounded=false;
    _g.physics(1/120);
    check(!_g.player.grounded && _g.player.py<440,"rising character can pass through underside");
    _g.reset(); _g.start();
    _g.stickers=[DreamTestGround(_g,750,230,405),DreamTestGround(_g,750,230,355)];
    _g.player.px=850; _g.player.py=340; _g.player.vy=1000; _g.player.grounded=false;
    repeat(4) _g.physics(1/120);
    check(_g.player.grounded && abs(_g.player.py-355)<0.1,"fall lands on uppermost crossed layer");
    // Slower movement still completes an alternating stair route over three screens.
    _g.reset(); _g.start();
    for(var xx=470;xx<_g.goal_left;xx+=175) {
        var height=405-((floor((xx-470)/175) mod 4)==1?24:0);
        array_push(_g.stickers,DreamTestGround(_g,xx,220,height));
    }
    repeat(5200) { if(_g.mode=="playing") _g.physics(1/120); }
    check(_g.mode=="won","full mixed-height route completes at reduced speed");

    var f=file_text_open_write("dream-v3-tests.txt");
    for(var i=0;i<array_length(result.lines);i++) { file_text_write_string(f,result.lines[i]); file_text_writeln(f); }
    file_text_write_string(f,"FAILURES="+string(result.failed)); file_text_close(f);
    _g.reset(); return result.failed;
}

function DreamTestGround(_g,_left,_width,_top) {
    var s=_g.make_sticker(0,0,0,0);
    s.w=(_width-12)/(_g.ground_widths[0]*2);
    s.h=s.w*_g.assets[0][0].h/_g.assets[0][0].w;
    s.px=_left+_width/2; s.top=_top-5; s.py=s.top+s.h/2; s.pulse=0;
    return s;
}
