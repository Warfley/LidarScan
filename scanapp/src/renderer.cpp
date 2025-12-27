#include <GL/glut.h>
#include <GL/glu.h>
#include <GL/gl.h>

void render_cloud(void) {
    glClear(GL_COLOR_BUFFER_BIT);
    glutSwapBuffers();
}

void start_renderer(int argc, char ** argv) {
    glutInit(&argc, argv);
    glutInitDisplayMode(GLUT_DOUBLE | GLUT_RGBA | GLUT_DEPTH);

    glutInitWindowSize(1024, 768);
    glutInitWindowPosition(100, 100);
    glutCreateWindow("Preview");
    glutDisplayFunc(render_cloud);
    glClearColor(170/255, 170/255, 1, 1);
    glutMainLoop();
}