function DreamRegression(_g) {
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
    repeat(3900) { if(_g.mode=="playing") _g.physics(1/120); }
    check(_g.mode=="won","full three-screen route reaches the exit");
    check(abs(_g.camera_x-(_g.level_width-_g.width))<0.01,"camera clamps at level end");
    var f=file_text_open_write("dream-v2-tests.txt");
    for(var i=0;i<array_length(result.lines);i++) { file_text_write_string(f,result.lines[i]); file_text_writeln(f); }
    file_text_write_string(f,"FAILURES="+string(result.failed)); file_text_close(f);
    _g.reset(); return result.failed;
}
