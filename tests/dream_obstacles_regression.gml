// Append with dream_v3_regression.gml to a temporary runtime build; not a shipped resource.
function DreamObstacleRegression(_g) {
    var result={lines:[],failed:0,check:function(ok,label) { array_push(lines,(ok?"PASS ":"FAIL ")+label); if(!ok) failed++; }};
    var check=result.check;
    _g.reset();
    check(array_length(_g.obstacles)==4,"four fixed hazards on reset");
    for(var i=0;i<4;i++) {
        var o=_g.obstacles[i];
        check(sprite_exists(_g.obstacle_art[i].sprite),"art loaded "+string(i));
        check(o.px>_g.start_right+300 && o.px<_g.goal_left-300,"safe start and ending "+string(i));
        check(o.py+o.h/2<_g.play_height,"hazard stays above library "+string(i));
        var contact=_g.obstacle_contact(o.cx,o.cy+33,o.cx,o.cy+33);
        check(contact.index==i,"body inside core detected "+string(i));
        contact=_g.obstacle_contact(o.cx-220,o.cy+33,o.cx+220,o.cy+33);
        check(contact.index==i && contact.time>0 && contact.time<1,"fast horizontal sweep "+string(i));
        contact=_g.obstacle_contact(o.cx,o.cy-200,o.cx,o.cy+200);
        check(contact.index==i,"fast vertical sweep "+string(i));
        contact=_g.obstacle_contact(o.cx-200,o.cy-o.ry-20,o.cx+200,o.cy-o.ry-20);
        check(contact.index<0,"generous route above tips "+string(i));
    }
    _g.start();
    var o=_g.obstacles[0];
    _g.player.px=o.cx-160; _g.player.py=o.cy+33; _g.player.vx=38400; _g.player.vy=0; _g.player.grounded=false;
    _g.drag={kind:0}; _g.physics(1/120);
    check(_g.mode=="lost" && _g.hit_obstacle==0 && is_undefined(_g.drag),"hit freezes and cancels drag");
    check(_g.player.px<o.cx,"stop at first contact, not other side");
    var stopx=_g.player.px; _g.physics(1/120);
    check(_g.player.px==stopx,"lost simulation is frozen");
    _g.reset(); _g.start();
    var cover=_g.make_sticker(0,0,900,460);
    check(_g.commit_sticker(cover),"decorative overlap remains placeable");
    _g.player.px=900; _g.player.py=440; _g.player.grounded=false;
    _g.physics(1/120);
    check(_g.mode=="lost","covering obstacle cannot remove danger");
    _g.reset();
    check(_g.hit_obstacle==-1 && _g.loss_time==0 && _g.obstacles[0].px==900,"retry restores fixed hazards and fade");
    check(!_g.begin_drag(0,_g.slots[0],_g.library_y),"hazards do not unlock pre-begin placement");
    _g.start();
    _g.player.px=900; _g.player.py=340; _g.mode="paused"; _g.physics(1/120);
    check(_g.mode=="paused" && _g.player.py==340,"pause freezes physics");
    // All-ground alternate solution: actual sticker dimensions, overlapping steps <=32px.
    DreamObstacleRoute(_g);
    var crossed=[false,false,false,false];
    repeat(5200) {
        if(_g.mode!="playing") break;
        _g.physics(1/120);
        for(var i=0;i<4;i++) if(_g.player.px>_g.obstacles[i].px+180) crossed[i]=true;
    }
    for(var i=0;i<4;i++) check(crossed[i],"ground route clears section "+string(i));
    check(_g.mode=="won","full route wins with all hazards active");
    // Spring route over second eye, with a generous landing sticker.
    for(var trial=0;trial<3;trial++) {
    _g.reset(); _g.start();
    var spring=_g.make_sticker(2,0,1636+trial*12,0);
    spring.top=400; spring.py=400+spring.h/2;
    // Catch the descending arc on a raised sticker; a floor-height landing here
    // would send the body back through the eye before reaching the far side.
    _g.stickers=[DreamObstacleGround(_g,1460,405),spring,DreamObstacleGround(_g,1720,309),DreamObstacleGround(_g,1920,341)];
    _g.player.px=1590; _g.player.py=405; _g.player.support=0;
    var launched=false;
    repeat(360) {
        if(_g.mode!="playing" || _g.player.px>1850) break;
        _g.physics(1/120); if(_g.player.state=="rise") launched=true;
    }
    check(launched && _g.mode=="playing" && _g.player.px>1850 && _g.player.grounded,"spring clears second eye and lands: "+string(launched)+" "+_g.mode+" x="+string(_g.player.px)+" y="+string(_g.player.py)+" hit="+string(_g.hit_obstacle));
    }
    // Hook route across final low hazard; no ground under the swing.
    for(var trial=0;trial<3;trial++) {
    _g.reset(); _g.start();
    _g.stickers=[_g.make_sticker(1,0,3200,145),DreamObstacleGround(_g,3310,405),DreamObstacleGround(_g,3510,405)];
    _g.player.px=3090+trial*10; _g.player.py=325; _g.player.grounded=false; _g.player.vy=0;
    var caught=false, released=false;
    repeat(480) {
        if(_g.mode!="playing" || (_g.player.px>3440 && _g.player.grounded)) break;
        _g.physics(1/120);
        if(_g.player.state=="swing") caught=true;
        if(caught && _g.player.state!="swing") released=true;
    }
    check(caught && released && _g.mode=="playing" && _g.player.px>3440 && _g.player.grounded,"hook clears last hazard, releases and lands: "+string(caught)+"/"+string(released)+" "+_g.mode+" x="+string(_g.player.px)+" y="+string(_g.player.py)+" hit="+string(_g.hit_obstacle));
    }
    var f=file_text_open_write("dream-obstacles-tests.txt");
    for(var i=0;i<array_length(result.lines);i++) { file_text_write_string(f,result.lines[i]); file_text_writeln(f); }
    file_text_write_string(f,"FAILURES="+string(result.failed)); file_text_close(f);
    _g.reset(); return result.failed;
}

function DreamObstacleGround(_g,_left,_top) {
    var s=_g.make_sticker(0,0,0,0);
    s.px=_left+s.w*_g.ground_widths[0]+6;
    s.top=_top-5; s.py=s.top+s.h/2; s.pulse=0;
    return s;
}

function DreamObstacleRoute(_g) {
    _g.reset(); _g.start();
    for(var xx=450;xx<_g.goal_left;xx+=100) {
        var top=405;
        if(xx>=550 && xx<1150) top=xx<650?381:(xx<750?357:(xx<1050?333:357));
        if(xx>=1150 && xx<1250) top=381;
        if(xx>=1350 && xx<2150) top=xx<1450?373:(xx<1550?341:(xx<1650?309:(xx<1850?277:(xx<1950?309:(xx<2050?341:373)))));
        if(xx>=2850 && xx<3550) top=xx<2950?381:(xx<3050?357:(xx<3350?333:(xx<3450?357:381)));
        array_push(_g.stickers,DreamObstacleGround(_g,xx,top));
    }
}
